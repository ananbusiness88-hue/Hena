BEGIN;

ALTER TYPE public.store_category ADD VALUE IF NOT EXISTS 'butcher_meat';
ALTER TYPE public.store_category ADD VALUE IF NOT EXISTS 'snacks';
ALTER TYPE public.store_category ADD VALUE IF NOT EXISTS 'restaurants';
ALTER TYPE public.store_category ADD VALUE IF NOT EXISTS 'card_recharge';
ALTER TYPE public.store_category ADD VALUE IF NOT EXISTS 'cigarettes';
ALTER TYPE public.store_category ADD VALUE IF NOT EXISTS 'stationery';
ALTER TYPE public.store_category ADD VALUE IF NOT EXISTS 'cleaning_household';
ALTER TYPE public.store_category ADD VALUE IF NOT EXISTS 'herbs_spices';

COMMIT;
