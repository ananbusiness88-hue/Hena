-- ============================================================================
-- Restore missing public.offers table on remote databases.
-- The initial schema migration is already marked as applied remotely,
-- but the table is missing there.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL,
  store_id uuid NOT NULL,
  title text NOT NULL,
  description text,
  original_price numeric(12,2) NOT NULL
    CHECK (original_price > 0),
  offer_price numeric(12,2) NOT NULL
    CHECK (offer_price > 0 AND offer_price < original_price),
  image_url text,
  start_date timestamptz NOT NULL,
  end_date timestamptz NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT offers_date_range
    CHECK (end_date > start_date),

  CONSTRAINT offers_product_store_fk
    FOREIGN KEY (product_id, store_id)
    REFERENCES public.products(id, store_id)
    ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_offers_product_id
  ON public.offers(product_id);

CREATE INDEX IF NOT EXISTS idx_offers_store_id
  ON public.offers(store_id);

CREATE INDEX IF NOT EXISTS idx_offers_active_dates
  ON public.offers(store_id, is_active, end_date);
