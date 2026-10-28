-- ============================================================================
-- ORDER ITEMS: OFFER SUPPORT
-- ============================================================================

ALTER TABLE public.order_items
ADD COLUMN offer_id uuid NULL;

ALTER TABLE public.order_items
ADD CONSTRAINT order_items_offer_id_fkey
FOREIGN KEY (offer_id)
REFERENCES public.offers(id)
ON DELETE RESTRICT;

CREATE INDEX idx_order_items_offer_id
ON public.order_items(offer_id);

-- ============================================================================
-- VALIDATE ORDER ITEM
-- ============================================================================
-- For normal products:
--   unit_price = current products.price
--
-- For offer products:
--   unit_price = offers.offer_price
--
-- Existing order items remain valid because offer_id is nullable.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.validate_order_item()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $function$
DECLARE
  v_product public.products%ROWTYPE;
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
      AND is_active = true
      AND start_date <= now()
      AND end_date > now();

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Offer not found, inactive, expired, or does not belong to this product';
    END IF;

    NEW.unit_price := v_offer.offer_price;
  ELSE
    NEW.unit_price := v_product.price;
  END IF;

  NEW.product_name := v_product.name;

  RETURN NEW;
END;
$function$;
