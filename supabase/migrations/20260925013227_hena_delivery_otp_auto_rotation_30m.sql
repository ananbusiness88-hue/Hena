-- ============================================================
-- HENA: Automatic Delivery OTP Rotation Every 30 Minutes
-- ============================================================

-- 1) Enable pg_cron locally / safely on environments where available.
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;

-- 2) Private schema for OTP rotation secrets.
CREATE SCHEMA IF NOT EXISTS private;

REVOKE ALL ON SCHEMA private FROM PUBLIC;
REVOKE ALL ON SCHEMA private FROM anon;
REVOKE ALL ON SCHEMA private FROM authenticated;

-- 3) Store a per-order secret outside the exposed public schema.
CREATE TABLE IF NOT EXISTS private.order_delivery_otp_secrets (
    order_id uuid PRIMARY KEY
        REFERENCES public.order_delivery_otp(order_id)
        ON DELETE CASCADE,
    seed bytea NOT NULL,
    rotation_anchor_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE private.order_delivery_otp_secrets ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE private.order_delivery_otp_secrets FROM PUBLIC;
REVOKE ALL ON TABLE private.order_delivery_otp_secrets FROM anon;
REVOKE ALL ON TABLE private.order_delivery_otp_secrets FROM authenticated;
GRANT USAGE ON SCHEMA private TO postgres;

-- ============================================================
-- 4) Deterministic OTP for the current 30-minute slot.
--    The plaintext OTP is never stored.
-- ============================================================

CREATE OR REPLACE FUNCTION private.delivery_otp_code(
    p_order_id uuid,
    p_seed bytea,
    p_anchor_at timestamptz,
    p_at timestamptz DEFAULT now()
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
STRICT
SET search_path TO pg_catalog, private, public, extensions
AS $function$
DECLARE
    v_slot bigint;
    v_digest bytea;
    v_number bigint;
BEGIN
    IF p_at < p_anchor_at THEN
        v_slot := 0;
    ELSE
        v_slot := floor(
            extract(epoch FROM (p_at - p_anchor_at)) / 1800
        )::bigint;
    END IF;

    v_digest := extensions.hmac(
        convert_to(
            p_order_id::text || ':' || v_slot::text,
            'utf8'
        ),
        p_seed,
        'sha256'
    );

    v_number :=
          get_byte(v_digest, 0)::bigint * 16777216
        + get_byte(v_digest, 1)::bigint * 65536
        + get_byte(v_digest, 2)::bigint * 256
        + get_byte(v_digest, 3)::bigint;

    RETURN lpad(
        (v_number % 10000)::text,
        4,
        '0'
    );
END;
$function$;

REVOKE ALL ON FUNCTION private.delivery_otp_code(
    uuid,
    bytea,
    timestamptz,
    timestamptz
) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 5) Synchronize the current OTP for one order.
--    This function is idempotent inside the same 30-minute slot.
-- ============================================================

CREATE OR REPLACE FUNCTION private.sync_delivery_otp(
    p_order_id uuid,
    p_at timestamptz DEFAULT now()
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, private, public, extensions
AS $function$
DECLARE
    v_seed bytea;
    v_anchor_at timestamptz;
    v_otp text;
    v_expires_at timestamptz;
    v_slot bigint;
BEGIN
    SELECT
        seed,
        rotation_anchor_at
    INTO
        v_seed,
        v_anchor_at
    FROM private.order_delivery_otp_secrets
    WHERE order_id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        v_seed := extensions.gen_random_bytes(32);
        v_anchor_at := p_at;

        INSERT INTO private.order_delivery_otp_secrets (
            order_id,
            seed,
            rotation_anchor_at
        )
        VALUES (
            p_order_id,
            v_seed,
            v_anchor_at
        )
        ON CONFLICT (order_id) DO NOTHING;

        SELECT
            seed,
            rotation_anchor_at
        INTO
            v_seed,
            v_anchor_at
        FROM private.order_delivery_otp_secrets
        WHERE order_id = p_order_id
        FOR UPDATE;
    END IF;

    IF p_at < v_anchor_at THEN
        v_slot := 0;
    ELSE
        v_slot := floor(
            extract(epoch FROM (p_at - v_anchor_at)) / 1800
        )::bigint;
    END IF;

    v_otp := private.delivery_otp_code(
        p_order_id,
        v_seed,
        v_anchor_at,
        p_at
    );

    v_expires_at :=
        v_anchor_at
        + (v_slot * interval '30 minutes')
        + interval '30 minutes';

    INSERT INTO public.order_delivery_otp (
        order_id,
        otp_hash,
        expires_at,
        attempts_count,
        max_attempts,
        verified_at,
        updated_at
    )
    VALUES (
        p_order_id,
        encode(
            extensions.digest(v_otp, 'sha256'),
            'hex'
        ),
        v_expires_at,
        0,
        5,
        NULL,
        now()
    )
    ON CONFLICT (order_id)
    DO UPDATE SET
        otp_hash = EXCLUDED.otp_hash,
        expires_at = EXCLUDED.expires_at,
        attempts_count =
            CASE
                WHEN public.order_delivery_otp.otp_hash
                     IS DISTINCT FROM EXCLUDED.otp_hash
                THEN 0
                ELSE public.order_delivery_otp.attempts_count
            END,
        verified_at =
            CASE
                WHEN public.order_delivery_otp.otp_hash
                     IS DISTINCT FROM EXCLUDED.otp_hash
                THEN NULL
                ELSE public.order_delivery_otp.verified_at
            END,
        updated_at =
            CASE
                WHEN public.order_delivery_otp.otp_hash
                     IS DISTINCT FROM EXCLUDED.otp_hash
                THEN now()
                ELSE public.order_delivery_otp.updated_at
            END
    WHERE public.order_delivery_otp.otp_hash
          IS DISTINCT FROM EXCLUDED.otp_hash
       OR public.order_delivery_otp.expires_at
          IS DISTINCT FROM EXCLUDED.expires_at;

    RETURN v_otp;
END;
$function$;

REVOKE ALL ON FUNCTION private.sync_delivery_otp(
    uuid,
    timestamptz
) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 6) Automatic rotation worker.
--    Only active out-for-delivery orders are processed.
-- ============================================================

CREATE OR REPLACE FUNCTION public.rotate_delivery_otps()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, public, private, extensions
AS $function$
DECLARE
    v_order record;
    v_count integer := 0;
BEGIN
    FOR v_order IN
        SELECT id
        FROM public.orders
        WHERE status = 'out_for_delivery'::public.order_status
          AND driver_id IS NOT NULL
    LOOP
        PERFORM private.sync_delivery_otp(
            v_order.id,
            now()
        );

        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$function$;

REVOKE ALL ON FUNCTION public.rotate_delivery_otps()
FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 7) Customer OTP getter.
--    Same OTP during its current 30-minute window.
--    Automatically becomes a new OTP after expiry.
-- ============================================================

CREATE OR REPLACE FUNCTION public.customer_get_delivery_otp(
    p_order_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, public, private, extensions
AS $function$
DECLARE
    v_customer_id uuid;
    v_driver_id uuid;
    v_status public.order_status;
BEGIN
    SELECT
        customer_id,
        driver_id,
        status
    INTO
        v_customer_id,
        v_driver_id,
        v_status
    FROM public.orders
    WHERE id = p_order_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'OTP: ????? ??? ?????';
    END IF;

    IF v_customer_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'OTP: ??? ????? ??? ?????? ???? ??????';
    END IF;

    IF v_driver_id IS NULL THEN
        RAISE EXCEPTION 'OTP: ?? ??? ????? ????? ?????';
    END IF;

    IF v_status <> 'out_for_delivery'::public.order_status THEN
        RAISE EXCEPTION
            'OTP: ???? ????? ??????? ?? % ????? out_for_delivery',
            v_status;
    END IF;

    RETURN private.sync_delivery_otp(
        p_order_id,
        now()
    );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.customer_get_delivery_otp(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.customer_get_delivery_otp(uuid)
TO authenticated;

-- ============================================================
-- 8) Compatibility function.
--    Does not generate a manually-controlled OTP anymore.
--    It returns the current automatic OTP window.
-- ============================================================

CREATE OR REPLACE FUNCTION public.customer_create_delivery_otp(
    p_order_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, public, private, extensions
AS $function$
DECLARE
    v_customer_id uuid;
    v_order_status public.order_status;
BEGIN
    SELECT
        customer_id,
        status
    INTO
        v_customer_id,
        v_order_status
    FROM public.orders
    WHERE id = p_order_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found';
    END IF;

    IF v_customer_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'Order does not belong to current customer';
    END IF;

    IF v_order_status NOT IN (
        'ready'::public.order_status,
        'out_for_delivery'::public.order_status
    ) THEN
        RAISE EXCEPTION
            'OTP is only available when the order is ready for shipping or out for delivery';
    END IF;

    RETURN private.sync_delivery_otp(
        p_order_id,
        now()
    );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.customer_create_delivery_otp(uuid)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.customer_create_delivery_otp(uuid)
TO authenticated;

-- The legacy low-level creator is no longer part of the customer flow.
REVOKE EXECUTE ON FUNCTION public.create_delivery_otp(uuid, text)
FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 9) Initialize existing active delivery orders.
-- ============================================================

INSERT INTO private.order_delivery_otp_secrets (
    order_id,
    seed,
    rotation_anchor_at
)
SELECT
    o.id,
    extensions.gen_random_bytes(32),
    now()
FROM public.orders o
WHERE o.status = 'out_for_delivery'::public.order_status
  AND o.driver_id IS NOT NULL
ON CONFLICT (order_id) DO NOTHING;

SELECT public.rotate_delivery_otps();

-- ============================================================
-- 10) Cron: check every minute.
--     Actual OTP rotation happens every 30 minutes.
-- ============================================================

SELECT cron.schedule(
    'hena-delivery-otp-rotation-30m',
    '* * * * *',
    'SELECT public.rotate_delivery_otps();'
);
