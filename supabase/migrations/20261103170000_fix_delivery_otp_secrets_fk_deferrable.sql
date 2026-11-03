-- ============================================================
-- HENA: Fix delivery OTP secret foreign key violation (23503)
--
-- Symptom: the customer could not open the delivery code
-- ("تعذر إنشاء رمز التسليم"), the app showed:
--   insert or update on table "order_delivery_otp_secrets" violates
--   foreign key constraint "order_delivery_otp_secrets_order_id_fkey"
--
-- Root cause:
--   private.sync_delivery_otp() stores the per-order rotation secret
--   in private.order_delivery_otp_secrets BEFORE it writes the
--   matching public.order_delivery_otp row, while the secret table
--   references public.order_delivery_otp(order_id).
--   For every order that has no public delivery OTP row yet - which
--   is every new order, because the public row is only created by
--   this same function - the secret insert violated the foreign key.
--   The same failure aborted public.rotate_delivery_otps(), so the
--   30-minute OTP rotation never ran for any order.
--
-- Fix: keep the constraint, but check it at the end of the
-- transaction instead of on every statement. The parent row is
-- created later in the same transaction, so the constraint is
-- satisfied at commit and no functional change is needed.
-- ============================================================

ALTER TABLE private.order_delivery_otp_secrets
    DROP CONSTRAINT IF EXISTS order_delivery_otp_secrets_order_id_fkey;

ALTER TABLE private.order_delivery_otp_secrets
    ADD CONSTRAINT order_delivery_otp_secrets_order_id_fkey
    FOREIGN KEY (order_id)
    REFERENCES public.order_delivery_otp(order_id)
    ON DELETE CASCADE
    DEFERRABLE INITIALLY DEFERRED;
