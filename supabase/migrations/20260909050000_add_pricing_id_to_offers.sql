-- ============================================================================
-- OFFERS: LINK OFFER TO A SPECIFIC PRODUCT PRICING
-- ============================================================================

ALTER TABLE public.offers
ADD COLUMN pricing_id uuid NOT NULL;

ALTER TABLE public.offers
ADD CONSTRAINT offers_pricing_id_fkey
FOREIGN KEY (pricing_id)
REFERENCES public.product_pricing(id)
ON DELETE RESTRICT;

CREATE INDEX idx_offers_pricing_id
ON public.offers(pricing_id);

-- ============================================================================
-- VALIDATE OFFER PRODUCT / PRICING RELATIONSHIP
-- ============================================================================
-- The selected pricing must belong to the same product as the offer.
-- The existing offers_product_store_fk already guarantees that the product
-- belongs to the declared store.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.validate_offer()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $function$
DECLARE
  v_pricing public.product_pricing%ROWTYPE;
BEGIN
  SELECT *
  INTO v_pricing
  FROM public.product_pricing
  WHERE id = NEW.pricing_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pricing not found';
  END IF;

  IF v_pricing.product_id <> NEW.product_id THEN
    RAISE EXCEPTION 'Pricing does not belong to this product';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trigger_validate_offer
ON public.offers;

CREATE TRIGGER trigger_validate_offer
BEFORE INSERT OR UPDATE OF product_id, pricing_id
ON public.offers
FOR EACH ROW
EXECUTE FUNCTION public.validate_offer();
