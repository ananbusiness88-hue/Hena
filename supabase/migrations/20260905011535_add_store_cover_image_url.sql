-- Hena: add store cover image URL.

ALTER TABLE public.stores
ADD COLUMN IF NOT EXISTS cover_image_url text;