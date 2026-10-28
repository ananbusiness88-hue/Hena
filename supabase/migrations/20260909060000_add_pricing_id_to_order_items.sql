-- ============================================================================
-- ORDER ITEMS: LINK TO PRODUCT PRICING
-- ============================================================================

ALTER TABLE public.order_items
ADD COLUMN pricing_id uuid NOT NULL;

ALTER TABLE public.order_items
ADD CONSTRAINT order_items_pricing_id_fkey
FOREIGN KEY (pricing_id)
REFERENCES public.product_pricing(id)
ON DELETE RESTRICT;

CREATE INDEX idx_order_items_pricing_id
ON public.order_items(pricing_id);

-- ============================================================================
-- VALIDATE ORDER ITEM
-- ============================================================================
-- The pricing must belong to the same product.
-- If an offer is used, the offer must belong to the same product and
-- must target the exact same pricing option.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.validate_order_item()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $function$
DECLARE
  v_product public.products%ROWTYPE;
  v_pricing public.product_pricing%ROWTYPE;
  v_offer public.offers%ROWTYPE;
BEGIN
  SELECT *
  INTO v_product
  FROM public.products
  WHERE id = NEW.product_id
    AND store_id = NEW.store_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Product does not belong to this store';
  END IF;

  IF NOT v_product.is_active THEN
    RAISE EXCEPTION 'Product is inactive';
  END IF;

  IF NEW.selling_method <> v_product.selling_method THEN
    RAISE EXCEPTION 'Selling method does not match product';
  END IF;

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

  IF NOT v_pricing.is_active THEN
    RAISE EXCEPTION 'Pricing is inactive';
  END IF;

  IF NEW.quantity <= 0 THEN
    IF NEW.selling_method = 'value' THEN
      RAISE EXCEPTION 'Requested value must be greater than zero';
    ELSE
      RAISE EXCEPTION 'Quantity must be greater than zero';
    END IF;
  END IF;

  IF NEW.selling_method = 'weight'
     AND NEW.quantity > 100
  THEN
    RAISE EXCEPTION 'Invalid weight quantity';
  END IF;

  IF NEW.offer_id IS NOT NULL THEN
    SELECT *
    INTO v_offer
    FROM public.offers
    WHERE id = NEW.offer_id
      AND product_id = NEW.product_id
      AND store_id = NEW.store_id
      AND pricing_id = NEW.pricing_id
      AND is_active = true
      AND start_date <= now()
      AND end_date > now();

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Offer not found, inactive, expired, or does not match product pricing';
    END IF;

    NEW.unit_price := v_offer.offer_price;
  ELSE
    NEW.unit_price := v_pricing.price;
  END IF;

  NEW.product_name := v_product.name;

  RETURN NEW;
END;
$function$;
