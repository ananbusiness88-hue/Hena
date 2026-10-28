-- ============================================================
-- HENA --- Phase 1 Security Hardening
-- RLS capture + least-privilege grants + account-enumeration fix
--
-- Generated from the live remote schema dump of Hena-V2
-- (zbcguyqmdwrhfuzljzwb) so the production security posture becomes
-- reproducible from version control.
--
-- Idempotent. Runs inside the migration transaction.
-- ============================================================

BEGIN;

-- ============================================================
-- SECTION 1 --- Row Level Security on every public table
--
-- Before this migration, RLS was applied out-of-band and 52 of the
-- 111 policies were never captured in the migrations folder, so a
-- fresh `supabase db reset` rebuilt an UNPROTECTED database.
-- ============================================================
ALTER TABLE "public"."addresses" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."admin_notification_campaigns" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."customer_ratings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."delivery_settings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."driver_availability" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."driver_daily_limits" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."driver_ratings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."driver_rejections" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."offers" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."order_delivery_otp" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."order_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."order_status_history" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."order_store_parts" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."orders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."payment_proofs" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."payments" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."print_jobs" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."product_categories" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."product_pricing" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."recharge_services" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."role_applications" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."store_categories" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."store_ownership_transfers" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."store_ratings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."store_settings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."stores" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."user_fcm_tokens" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."user_passwords" ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- SECTION 2 --- All public policies, captured verbatim from live
-- DROP + CREATE makes this the single source of truth while keeping
-- the exact production semantics.
-- ============================================================
-- public.product_categories
DROP POLICY IF EXISTS "Active product categories are viewable" ON "public"."product_categories";
CREATE POLICY "Active product categories are viewable" ON "public"."product_categories" FOR SELECT USING ((("is_active" = true) AND (EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "product_categories"."store_id") AND ("s"."is_active" = true))))));

-- public.product_pricing
DROP POLICY IF EXISTS "Active product pricing is viewable" ON "public"."product_pricing";
CREATE POLICY "Active product pricing is viewable" ON "public"."product_pricing" FOR SELECT USING ((("is_active" = true) AND (EXISTS ( SELECT 1 FROM ("public"."products" "p" JOIN "public"."stores" "s" ON (("s"."id" = "p"."store_id"))) WHERE (("p"."id" = "product_pricing"."product_id") AND ("p"."is_active" = true) AND ("s"."is_active" = true))))));

-- public.store_categories
DROP POLICY IF EXISTS "Active store categories are viewable" ON "public"."store_categories";
CREATE POLICY "Active store categories are viewable" ON "public"."store_categories" FOR SELECT USING (("is_active" = true));

-- public.store_settings
DROP POLICY IF EXISTS "Active store settings are viewable" ON "public"."store_settings";
CREATE POLICY "Active store settings are viewable" ON "public"."store_settings" FOR SELECT USING ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "store_settings"."store_id") AND ("s"."is_active" = true)))));

-- public.product_categories
DROP POLICY IF EXISTS "Admins manage product categories" ON "public"."product_categories";
CREATE POLICY "Admins manage product categories" ON "public"."product_categories" TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."profiles" "p" WHERE (("p"."id" = "auth"."uid"()) AND ("p"."role" = 'admin'::"public"."user_role"))))) WITH CHECK ((EXISTS ( SELECT 1 FROM "public"."profiles" "p" WHERE (("p"."id" = "auth"."uid"()) AND ("p"."role" = 'admin'::"public"."user_role")))));

-- public.product_pricing
DROP POLICY IF EXISTS "Admins manage product pricing" ON "public"."product_pricing";
CREATE POLICY "Admins manage product pricing" ON "public"."product_pricing" TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."profiles" "p" WHERE (("p"."id" = "auth"."uid"()) AND ("p"."role" = 'admin'::"public"."user_role"))))) WITH CHECK ((EXISTS ( SELECT 1 FROM "public"."profiles" "p" WHERE (("p"."id" = "auth"."uid"()) AND ("p"."role" = 'admin'::"public"."user_role")))));

-- public.products
DROP POLICY IF EXISTS "Admins manage products" ON "public"."products";
CREATE POLICY "Admins manage products" ON "public"."products" TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."profiles" "p" WHERE (("p"."id" = "auth"."uid"()) AND ("p"."role" = 'admin'::"public"."user_role"))))) WITH CHECK ((EXISTS ( SELECT 1 FROM "public"."profiles" "p" WHERE (("p"."id" = "auth"."uid"()) AND ("p"."role" = 'admin'::"public"."user_role")))));

-- public.store_categories
DROP POLICY IF EXISTS "Admins manage store categories" ON "public"."store_categories";
CREATE POLICY "Admins manage store categories" ON "public"."store_categories" TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."profiles" "p" WHERE (("p"."id" = "auth"."uid"()) AND ("p"."role" = 'admin'::"public"."user_role"))))) WITH CHECK ((EXISTS ( SELECT 1 FROM "public"."profiles" "p" WHERE (("p"."id" = "auth"."uid"()) AND ("p"."role" = 'admin'::"public"."user_role")))));

-- public.store_settings
DROP POLICY IF EXISTS "Admins manage store settings" ON "public"."store_settings";
CREATE POLICY "Admins manage store settings" ON "public"."store_settings" TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."profiles" "p" WHERE (("p"."id" = "auth"."uid"()) AND ("p"."role" = 'admin'::"public"."user_role"))))) WITH CHECK ((EXISTS ( SELECT 1 FROM "public"."profiles" "p" WHERE (("p"."id" = "auth"."uid"()) AND ("p"."role" = 'admin'::"public"."user_role")))));

-- public.stores
DROP POLICY IF EXISTS "Admins manage stores" ON "public"."stores";
CREATE POLICY "Admins manage stores" ON "public"."stores" TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."profiles" "p" WHERE (("p"."id" = "auth"."uid"()) AND ("p"."role" = 'admin'::"public"."user_role"))))) WITH CHECK ((EXISTS ( SELECT 1 FROM "public"."profiles" "p" WHERE (("p"."id" = "auth"."uid"()) AND ("p"."role" = 'admin'::"public"."user_role")))));

-- public.profiles
DROP POLICY IF EXISTS "Users can create own profile" ON "public"."profiles";
CREATE POLICY "Users can create own profile" ON "public"."profiles" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "id"));

-- public.addresses
DROP POLICY IF EXISTS "addresses_admin" ON "public"."addresses";
CREATE POLICY "addresses_admin" ON "public"."addresses" FOR SELECT TO "authenticated" USING ("public"."is_admin"());

-- public.addresses
DROP POLICY IF EXISTS "addresses_delete_own" ON "public"."addresses";
CREATE POLICY "addresses_delete_own" ON "public"."addresses" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));

-- public.addresses
DROP POLICY IF EXISTS "addresses_insert_own" ON "public"."addresses";
CREATE POLICY "addresses_insert_own" ON "public"."addresses" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));

-- public.addresses
DROP POLICY IF EXISTS "addresses_select_own" ON "public"."addresses";
CREATE POLICY "addresses_select_own" ON "public"."addresses" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));

-- public.addresses
DROP POLICY IF EXISTS "addresses_update_own" ON "public"."addresses";
CREATE POLICY "addresses_update_own" ON "public"."addresses" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));

-- public.admin_notification_campaigns
DROP POLICY IF EXISTS "admin_notification_campaigns_select_admin" ON "public"."admin_notification_campaigns";
CREATE POLICY "admin_notification_campaigns_select_admin" ON "public"."admin_notification_campaigns" FOR SELECT TO "authenticated" USING (("public"."is_admin"() AND ("created_by" = "auth"."uid"())));

-- public.customer_ratings
DROP POLICY IF EXISTS "customer_ratings_insert_driver" ON "public"."customer_ratings";
CREATE POLICY "customer_ratings_insert_driver" ON "public"."customer_ratings" FOR INSERT TO "authenticated" WITH CHECK ((("driver_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1 FROM "public"."orders" "o" WHERE (("o"."id" = "customer_ratings"."order_id") AND ("o"."driver_id" = "auth"."uid"()) AND ("o"."customer_id" = "customer_ratings"."customer_id") AND ("o"."status" = 'delivered'::"public"."order_status"))))));

-- public.customer_ratings
DROP POLICY IF EXISTS "customer_ratings_select_participants" ON "public"."customer_ratings";
CREATE POLICY "customer_ratings_select_participants" ON "public"."customer_ratings" FOR SELECT TO "authenticated" USING ((("customer_id" = "auth"."uid"()) OR ("driver_id" = "auth"."uid"()) OR "public"."is_admin"()));

-- public.delivery_settings
DROP POLICY IF EXISTS "delivery_settings_select_authenticated" ON "public"."delivery_settings";
CREATE POLICY "delivery_settings_select_authenticated" ON "public"."delivery_settings" FOR SELECT TO "authenticated" USING (true);

-- public.driver_availability
DROP POLICY IF EXISTS "driver_availability_delete_own" ON "public"."driver_availability";
CREATE POLICY "driver_availability_delete_own" ON "public"."driver_availability" FOR DELETE TO "authenticated" USING (("driver_id" = "auth"."uid"()));

-- public.driver_availability
DROP POLICY IF EXISTS "driver_availability_insert_own" ON "public"."driver_availability";
CREATE POLICY "driver_availability_insert_own" ON "public"."driver_availability" FOR INSERT TO "authenticated" WITH CHECK (("driver_id" = "auth"."uid"()));

-- public.driver_availability
DROP POLICY IF EXISTS "driver_availability_select_own" ON "public"."driver_availability";
CREATE POLICY "driver_availability_select_own" ON "public"."driver_availability" FOR SELECT TO "authenticated" USING (("driver_id" = "auth"."uid"()));

-- public.driver_availability
DROP POLICY IF EXISTS "driver_availability_update_own" ON "public"."driver_availability";
CREATE POLICY "driver_availability_update_own" ON "public"."driver_availability" FOR UPDATE TO "authenticated" USING (("driver_id" = "auth"."uid"())) WITH CHECK (("driver_id" = "auth"."uid"()));

-- public.driver_daily_limits
DROP POLICY IF EXISTS "driver_daily_limits_admin" ON "public"."driver_daily_limits";
CREATE POLICY "driver_daily_limits_admin" ON "public"."driver_daily_limits" TO "authenticated" USING ("public"."is_admin"()) WITH CHECK ("public"."is_admin"());

-- public.driver_daily_limits
DROP POLICY IF EXISTS "driver_daily_limits_select_own" ON "public"."driver_daily_limits";
CREATE POLICY "driver_daily_limits_select_own" ON "public"."driver_daily_limits" FOR SELECT TO "authenticated" USING (("driver_id" = "auth"."uid"()));

-- public.driver_ratings
DROP POLICY IF EXISTS "driver_ratings_insert_customer" ON "public"."driver_ratings";
CREATE POLICY "driver_ratings_insert_customer" ON "public"."driver_ratings" FOR INSERT TO "authenticated" WITH CHECK ((("customer_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1 FROM "public"."orders" "o" WHERE (("o"."id" = "driver_ratings"."order_id") AND ("o"."customer_id" = "auth"."uid"()) AND ("o"."driver_id" = "driver_ratings"."driver_id") AND ("o"."status" = 'delivered'::"public"."order_status"))))));

-- public.driver_ratings
DROP POLICY IF EXISTS "driver_ratings_select_participants" ON "public"."driver_ratings";
CREATE POLICY "driver_ratings_select_participants" ON "public"."driver_ratings" FOR SELECT TO "authenticated" USING ((("driver_id" = "auth"."uid"()) OR ("customer_id" = "auth"."uid"()) OR "public"."is_admin"()));

-- public.driver_rejections
DROP POLICY IF EXISTS "driver_rejections_insert_own" ON "public"."driver_rejections";
CREATE POLICY "driver_rejections_insert_own" ON "public"."driver_rejections" FOR INSERT TO "authenticated" WITH CHECK ((("driver_id" = "auth"."uid"()) AND ("rejection_date" = CURRENT_DATE) AND (EXISTS ( SELECT 1 FROM "public"."orders" "o" WHERE (("o"."id" = "driver_rejections"."order_id") AND ("o"."driver_id" = "auth"."uid"()) AND ("o"."status" = ANY (ARRAY['assigned'::"public"."order_status", 'confirmed'::"public"."order_status", 'preparing'::"public"."order_status", 'ready'::"public"."order_status"])))))));

-- public.driver_rejections
DROP POLICY IF EXISTS "driver_rejections_select_own" ON "public"."driver_rejections";
CREATE POLICY "driver_rejections_select_own" ON "public"."driver_rejections" FOR SELECT TO "authenticated" USING (("driver_id" = "auth"."uid"()));

-- public.notifications
DROP POLICY IF EXISTS "notifications_insert_admin" ON "public"."notifications";
CREATE POLICY "notifications_insert_admin" ON "public"."notifications" FOR INSERT TO "authenticated" WITH CHECK ("public"."is_admin"());

-- public.notifications
DROP POLICY IF EXISTS "notifications_select_own" ON "public"."notifications";
CREATE POLICY "notifications_select_own" ON "public"."notifications" FOR SELECT TO "authenticated" USING (("recipient_user_id" = "auth"."uid"()));

-- public.notifications
DROP POLICY IF EXISTS "notifications_update_own" ON "public"."notifications";
CREATE POLICY "notifications_update_own" ON "public"."notifications" FOR UPDATE TO "authenticated" USING (("recipient_user_id" = "auth"."uid"())) WITH CHECK (("recipient_user_id" = "auth"."uid"()));

-- public.offers
DROP POLICY IF EXISTS "offers_insert_admin" ON "public"."offers";
CREATE POLICY "offers_insert_admin" ON "public"."offers" FOR INSERT TO "authenticated" WITH CHECK ("public"."is_admin"());

-- public.offers
DROP POLICY IF EXISTS "offers_insert_owner" ON "public"."offers";
CREATE POLICY "offers_insert_owner" ON "public"."offers" FOR INSERT TO "authenticated" WITH CHECK ((("approval_status" = 'pending'::"text") AND ("is_active" = false) AND (EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "offers"."store_id") AND ("s"."owner_id" = "auth"."uid"())))) AND (EXISTS ( SELECT 1 FROM "public"."products" "p" WHERE (("p"."id" = "offers"."product_id") AND ("p"."store_id" = "offers"."store_id"))))));

-- public.offers
DROP POLICY IF EXISTS "offers_select_active" ON "public"."offers";
CREATE POLICY "offers_select_active" ON "public"."offers" FOR SELECT TO "authenticated", "anon" USING ((("approval_status" = 'approved'::"text") AND ("is_active" = true) AND ("start_date" <= "now"()) AND ("end_date" > "now"()) AND (EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "offers"."store_id") AND ("s"."is_active" = true))))));

-- public.offers
DROP POLICY IF EXISTS "offers_select_admin" ON "public"."offers";
CREATE POLICY "offers_select_admin" ON "public"."offers" FOR SELECT TO "authenticated" USING ("public"."is_admin"());

-- public.offers
DROP POLICY IF EXISTS "offers_select_owner" ON "public"."offers";
CREATE POLICY "offers_select_owner" ON "public"."offers" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "offers"."store_id") AND ("s"."owner_id" = "auth"."uid"())))));

-- public.offers
DROP POLICY IF EXISTS "offers_update_admin" ON "public"."offers";
CREATE POLICY "offers_update_admin" ON "public"."offers" FOR UPDATE TO "authenticated" USING ("public"."is_admin"()) WITH CHECK ("public"."is_admin"());

-- public.offers
DROP POLICY IF EXISTS "offers_update_owner" ON "public"."offers";
CREATE POLICY "offers_update_owner" ON "public"."offers" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "offers"."store_id") AND ("s"."owner_id" = "auth"."uid"()))))) WITH CHECK ((("approval_status" = 'pending'::"text") AND ("is_active" = false) AND (EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "offers"."store_id") AND ("s"."owner_id" = "auth"."uid"())))) AND (EXISTS ( SELECT 1 FROM "public"."products" "p" WHERE (("p"."id" = "offers"."product_id") AND ("p"."store_id" = "offers"."store_id"))))));

-- public.order_items
DROP POLICY IF EXISTS "order_items_select_admin" ON "public"."order_items";
CREATE POLICY "order_items_select_admin" ON "public"."order_items" FOR SELECT TO "authenticated" USING ("public"."is_admin"());

-- public.order_items
DROP POLICY IF EXISTS "order_items_select_customer" ON "public"."order_items";
CREATE POLICY "order_items_select_customer" ON "public"."order_items" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."orders" "o" WHERE (("o"."id" = "order_items"."order_id") AND ("o"."customer_id" = "auth"."uid"())))));

-- public.order_items
DROP POLICY IF EXISTS "order_items_select_driver" ON "public"."order_items";
CREATE POLICY "order_items_select_driver" ON "public"."order_items" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."orders" "o" WHERE (("o"."id" = "order_items"."order_id") AND (("o"."driver_id" = "auth"."uid"()) OR (("o"."status" = 'ready'::"public"."order_status") AND ("o"."driver_id" IS NULL)))))));

-- public.order_items
DROP POLICY IF EXISTS "order_items_select_store_owner" ON "public"."order_items";
CREATE POLICY "order_items_select_store_owner" ON "public"."order_items" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "order_items"."store_id") AND ("s"."owner_id" = "auth"."uid"())))));

-- public.order_status_history
DROP POLICY IF EXISTS "order_status_history_admin" ON "public"."order_status_history";
CREATE POLICY "order_status_history_admin" ON "public"."order_status_history" FOR SELECT TO "authenticated" USING ("public"."is_admin"());

-- public.order_status_history
DROP POLICY IF EXISTS "order_status_history_select_customer" ON "public"."order_status_history";
CREATE POLICY "order_status_history_select_customer" ON "public"."order_status_history" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."orders" "o" WHERE (("o"."id" = "order_status_history"."order_id") AND ("o"."customer_id" = "auth"."uid"())))));

-- public.order_status_history
DROP POLICY IF EXISTS "order_status_history_select_driver" ON "public"."order_status_history";
CREATE POLICY "order_status_history_select_driver" ON "public"."order_status_history" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."orders" "o" WHERE (("o"."id" = "order_status_history"."order_id") AND ("o"."driver_id" = "auth"."uid"())))));

-- public.order_status_history
DROP POLICY IF EXISTS "order_status_history_select_store_owner" ON "public"."order_status_history";
CREATE POLICY "order_status_history_select_store_owner" ON "public"."order_status_history" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1 FROM ("public"."orders" "o" JOIN "public"."stores" "s" ON (("s"."id" = "o"."store_id"))) WHERE (("o"."id" = "order_status_history"."order_id") AND ("s"."owner_id" = "auth"."uid"())))));

-- public.order_store_parts
DROP POLICY IF EXISTS "order_store_parts_select_admin" ON "public"."order_store_parts";
CREATE POLICY "order_store_parts_select_admin" ON "public"."order_store_parts" FOR SELECT TO "authenticated" USING ("public"."is_admin"());

-- public.order_store_parts
DROP POLICY IF EXISTS "order_store_parts_select_customer" ON "public"."order_store_parts";
CREATE POLICY "order_store_parts_select_customer" ON "public"."order_store_parts" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."orders" "o" WHERE (("o"."id" = "order_store_parts"."order_id") AND ("o"."customer_id" = "auth"."uid"())))));

-- public.order_store_parts
DROP POLICY IF EXISTS "order_store_parts_select_driver" ON "public"."order_store_parts";
CREATE POLICY "order_store_parts_select_driver" ON "public"."order_store_parts" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."orders" "o" WHERE (("o"."id" = "order_store_parts"."order_id") AND (("o"."driver_id" = "auth"."uid"()) OR (("o"."status" = 'ready'::"public"."order_status") AND ("o"."driver_id" IS NULL)))))));

-- public.order_store_parts
DROP POLICY IF EXISTS "order_store_parts_select_store_owner" ON "public"."order_store_parts";
CREATE POLICY "order_store_parts_select_store_owner" ON "public"."order_store_parts" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "order_store_parts"."store_id") AND ("s"."owner_id" = "auth"."uid"())))));

-- public.order_store_parts
DROP POLICY IF EXISTS "order_store_parts_update_admin" ON "public"."order_store_parts";
CREATE POLICY "order_store_parts_update_admin" ON "public"."order_store_parts" FOR UPDATE TO "authenticated" USING ("public"."is_admin"()) WITH CHECK ("public"."is_admin"());

-- public.order_store_parts
DROP POLICY IF EXISTS "order_store_parts_update_driver" ON "public"."order_store_parts";
CREATE POLICY "order_store_parts_update_driver" ON "public"."order_store_parts" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."orders" "o" WHERE (("o"."id" = "order_store_parts"."order_id") AND ("o"."driver_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1 FROM "public"."orders" "o" WHERE (("o"."id" = "order_store_parts"."order_id") AND ("o"."driver_id" = "auth"."uid"())))));

-- public.order_store_parts
DROP POLICY IF EXISTS "order_store_parts_update_store_owner" ON "public"."order_store_parts";
CREATE POLICY "order_store_parts_update_store_owner" ON "public"."order_store_parts" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "order_store_parts"."store_id") AND ("s"."owner_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "order_store_parts"."store_id") AND ("s"."owner_id" = "auth"."uid"())))));

-- public.orders
DROP POLICY IF EXISTS "orders_select_admin" ON "public"."orders";
CREATE POLICY "orders_select_admin" ON "public"."orders" FOR SELECT TO "authenticated" USING ("public"."is_admin"());

-- public.orders
DROP POLICY IF EXISTS "orders_select_customer" ON "public"."orders";
CREATE POLICY "orders_select_customer" ON "public"."orders" FOR SELECT TO "authenticated" USING (("customer_id" = "auth"."uid"()));

-- public.orders
DROP POLICY IF EXISTS "orders_select_driver" ON "public"."orders";
CREATE POLICY "orders_select_driver" ON "public"."orders" FOR SELECT TO "authenticated" USING ((("driver_id" = "auth"."uid"()) OR (("status" = 'ready'::"public"."order_status") AND ("driver_id" IS NULL))));

-- public.orders
DROP POLICY IF EXISTS "orders_select_store_owner" ON "public"."orders";
CREATE POLICY "orders_select_store_owner" ON "public"."orders" FOR SELECT TO "authenticated" USING ("public"."is_store_owner_of_order"("id"));

-- public.orders
DROP POLICY IF EXISTS "orders_update_admin" ON "public"."orders";
CREATE POLICY "orders_update_admin" ON "public"."orders" FOR UPDATE TO "authenticated" USING ("public"."is_admin"()) WITH CHECK ("public"."is_admin"());

-- public.orders
DROP POLICY IF EXISTS "orders_update_customer" ON "public"."orders";
CREATE POLICY "orders_update_customer" ON "public"."orders" FOR UPDATE TO "authenticated" USING ((("customer_id" = "auth"."uid"()) AND ("status" = ANY (ARRAY['pending'::"public"."order_status", 'confirmed'::"public"."order_status"])) AND ("created_at" >= ("now"() - '00:01:30'::interval)))) WITH CHECK ((("customer_id" = "auth"."uid"()) AND ("status" = ANY (ARRAY['pending'::"public"."order_status", 'confirmed'::"public"."order_status", 'cancelled'::"public"."order_status"])) AND ("created_at" >= ("now"() - '00:01:30'::interval))));

-- public.orders
DROP POLICY IF EXISTS "orders_update_driver" ON "public"."orders";
CREATE POLICY "orders_update_driver" ON "public"."orders" FOR UPDATE TO "authenticated" USING (("driver_id" = "auth"."uid"())) WITH CHECK ((("driver_id" = "auth"."uid"()) AND ("status" = ANY (ARRAY['assigned'::"public"."order_status", 'picked_up'::"public"."order_status", 'out_for_delivery'::"public"."order_status"]))));

-- public.order_delivery_otp
DROP POLICY IF EXISTS "otp_admin_select" ON "public"."order_delivery_otp";
CREATE POLICY "otp_admin_select" ON "public"."order_delivery_otp" FOR SELECT TO "authenticated" USING ("public"."is_admin"());

-- public.payment_proofs
DROP POLICY IF EXISTS "payment_proofs_select_admin" ON "public"."payment_proofs";
CREATE POLICY "payment_proofs_select_admin" ON "public"."payment_proofs" FOR SELECT TO "authenticated" USING ("public"."is_admin"());

-- public.payment_proofs
DROP POLICY IF EXISTS "payment_proofs_select_customer" ON "public"."payment_proofs";
CREATE POLICY "payment_proofs_select_customer" ON "public"."payment_proofs" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1 FROM ("public"."payments" "p" JOIN "public"."orders" "o" ON (("o"."id" = "p"."order_id"))) WHERE (("p"."id" = "payment_proofs"."payment_id") AND ("o"."customer_id" = "auth"."uid"())))));

-- public.payments
DROP POLICY IF EXISTS "payments_select_admin" ON "public"."payments";
CREATE POLICY "payments_select_admin" ON "public"."payments" FOR SELECT TO "authenticated" USING ("public"."is_admin"());

-- public.payments
DROP POLICY IF EXISTS "payments_select_customer" ON "public"."payments";
CREATE POLICY "payments_select_customer" ON "public"."payments" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."orders" "o" WHERE (("o"."id" = "payments"."order_id") AND ("o"."customer_id" = "auth"."uid"())))));

-- public.payments
DROP POLICY IF EXISTS "payments_select_driver" ON "public"."payments";
CREATE POLICY "payments_select_driver" ON "public"."payments" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."orders" "o" WHERE (("o"."id" = "payments"."order_id") AND ("o"."driver_id" = "auth"."uid"())))));

-- public.payments
DROP POLICY IF EXISTS "payments_select_store_owner" ON "public"."payments";
CREATE POLICY "payments_select_store_owner" ON "public"."payments" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1 FROM ("public"."orders" "o" JOIN "public"."stores" "s" ON (("s"."id" = "o"."store_id"))) WHERE (("o"."id" = "payments"."order_id") AND ("s"."owner_id" = "auth"."uid"())))));

-- public.product_categories
DROP POLICY IF EXISTS "product_categories_delete_owner" ON "public"."product_categories";
CREATE POLICY "product_categories_delete_owner" ON "public"."product_categories" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "product_categories"."store_id") AND ("s"."owner_id" = "auth"."uid"())))));

-- public.product_categories
DROP POLICY IF EXISTS "product_categories_insert_owner" ON "public"."product_categories";
CREATE POLICY "product_categories_insert_owner" ON "public"."product_categories" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "product_categories"."store_id") AND ("s"."owner_id" = "auth"."uid"())))));

-- public.product_categories
DROP POLICY IF EXISTS "product_categories_update_owner" ON "public"."product_categories";
CREATE POLICY "product_categories_update_owner" ON "public"."product_categories" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "product_categories"."store_id") AND ("s"."owner_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "product_categories"."store_id") AND ("s"."owner_id" = "auth"."uid"())))));

-- public.product_pricing
DROP POLICY IF EXISTS "product_pricing_delete_owner" ON "public"."product_pricing";
CREATE POLICY "product_pricing_delete_owner" ON "public"."product_pricing" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1 FROM ("public"."products" "p" JOIN "public"."stores" "s" ON (("s"."id" = "p"."store_id"))) WHERE (("p"."id" = "product_pricing"."product_id") AND ("s"."owner_id" = "auth"."uid"())))));

-- public.product_pricing
DROP POLICY IF EXISTS "product_pricing_insert_owner" ON "public"."product_pricing";
CREATE POLICY "product_pricing_insert_owner" ON "public"."product_pricing" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1 FROM ("public"."products" "p" JOIN "public"."stores" "s" ON (("s"."id" = "p"."store_id"))) WHERE (("p"."id" = "product_pricing"."product_id") AND ("s"."owner_id" = "auth"."uid"())))));

-- public.product_pricing
DROP POLICY IF EXISTS "product_pricing_update_owner" ON "public"."product_pricing";
CREATE POLICY "product_pricing_update_owner" ON "public"."product_pricing" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1 FROM ("public"."products" "p" JOIN "public"."stores" "s" ON (("s"."id" = "p"."store_id"))) WHERE (("p"."id" = "product_pricing"."product_id") AND ("s"."owner_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1 FROM ("public"."products" "p" JOIN "public"."stores" "s" ON (("s"."id" = "p"."store_id"))) WHERE (("p"."id" = "product_pricing"."product_id") AND ("s"."owner_id" = "auth"."uid"())))));

-- public.products
DROP POLICY IF EXISTS "products_delete_owner" ON "public"."products";
CREATE POLICY "products_delete_owner" ON "public"."products" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "products"."store_id") AND ("s"."owner_id" = "auth"."uid"())))));

-- public.products
DROP POLICY IF EXISTS "products_insert_owner" ON "public"."products";
CREATE POLICY "products_insert_owner" ON "public"."products" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "products"."store_id") AND ("s"."owner_id" = "auth"."uid"())))));

-- public.products
DROP POLICY IF EXISTS "products_select_active" ON "public"."products";
CREATE POLICY "products_select_active" ON "public"."products" FOR SELECT TO "authenticated", "anon" USING ((("is_active" = true) AND (EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "products"."store_id") AND ("s"."is_active" = true))))));

-- public.products
DROP POLICY IF EXISTS "products_select_admin" ON "public"."products";
CREATE POLICY "products_select_admin" ON "public"."products" FOR SELECT TO "authenticated" USING ("public"."is_admin"());

-- public.products
DROP POLICY IF EXISTS "products_select_owner" ON "public"."products";
CREATE POLICY "products_select_owner" ON "public"."products" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "products"."store_id") AND ("s"."owner_id" = "auth"."uid"())))));

-- public.products
DROP POLICY IF EXISTS "products_update_admin" ON "public"."products";
CREATE POLICY "products_update_admin" ON "public"."products" FOR UPDATE TO "authenticated" USING ("public"."is_admin"()) WITH CHECK ("public"."is_admin"());

-- public.products
DROP POLICY IF EXISTS "products_update_owner" ON "public"."products";
CREATE POLICY "products_update_owner" ON "public"."products" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "products"."store_id") AND ("s"."owner_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "products"."store_id") AND ("s"."owner_id" = "auth"."uid"())))));

-- public.profiles
DROP POLICY IF EXISTS "profiles_select_admin" ON "public"."profiles";
CREATE POLICY "profiles_select_admin" ON "public"."profiles" FOR SELECT TO "authenticated" USING ("public"."is_admin"());

-- public.profiles
DROP POLICY IF EXISTS "profiles_select_own" ON "public"."profiles";
CREATE POLICY "profiles_select_own" ON "public"."profiles" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "id"));

-- public.profiles
DROP POLICY IF EXISTS "profiles_update_admin" ON "public"."profiles";
CREATE POLICY "profiles_update_admin" ON "public"."profiles" FOR UPDATE TO "authenticated" USING ("public"."is_admin"()) WITH CHECK ("public"."is_admin"());

-- public.profiles
DROP POLICY IF EXISTS "profiles_update_own" ON "public"."profiles";
CREATE POLICY "profiles_update_own" ON "public"."profiles" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "id")) WITH CHECK ((("auth"."uid"() = "id") AND ("role" = "public"."current_user_role"())));

-- public.recharge_services
DROP POLICY IF EXISTS "recharge_insert_customer" ON "public"."recharge_services";
CREATE POLICY "recharge_insert_customer" ON "public"."recharge_services" FOR INSERT TO "authenticated" WITH CHECK ((("customer_id" = "auth"."uid"()) AND ("status" = 'pending'::"public"."order_status")));

-- public.recharge_services
DROP POLICY IF EXISTS "recharge_select_admin" ON "public"."recharge_services";
CREATE POLICY "recharge_select_admin" ON "public"."recharge_services" FOR SELECT TO "authenticated" USING ("public"."is_admin"());

-- public.recharge_services
DROP POLICY IF EXISTS "recharge_select_customer" ON "public"."recharge_services";
CREATE POLICY "recharge_select_customer" ON "public"."recharge_services" FOR SELECT TO "authenticated" USING (("customer_id" = "auth"."uid"()));

-- public.role_applications
DROP POLICY IF EXISTS "role_applications_admin" ON "public"."role_applications";
CREATE POLICY "role_applications_admin" ON "public"."role_applications" FOR SELECT TO "authenticated" USING ("public"."is_admin"());

-- public.role_applications
DROP POLICY IF EXISTS "role_applications_insert_own" ON "public"."role_applications";
CREATE POLICY "role_applications_insert_own" ON "public"."role_applications" FOR INSERT TO "authenticated" WITH CHECK ((("applicant_id" = "auth"."uid"()) AND ("requested_role" = ANY (ARRAY['driver'::"public"."user_role", 'store_owner'::"public"."user_role"])) AND ("status" = 'pending'::"public"."role_application_status")));

-- public.role_applications
DROP POLICY IF EXISTS "role_applications_select_own" ON "public"."role_applications";
CREATE POLICY "role_applications_select_own" ON "public"."role_applications" FOR SELECT TO "authenticated" USING (("applicant_id" = "auth"."uid"()));

-- public.print_jobs
DROP POLICY IF EXISTS "store_owners_select_own_print_jobs" ON "public"."print_jobs";
CREATE POLICY "store_owners_select_own_print_jobs" ON "public"."print_jobs" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "print_jobs"."store_id") AND ("s"."owner_id" = ( SELECT "auth"."uid"() AS "uid"))))));

-- public.print_jobs
DROP POLICY IF EXISTS "store_owners_update_own_print_jobs" ON "public"."print_jobs";
CREATE POLICY "store_owners_update_own_print_jobs" ON "public"."print_jobs" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "print_jobs"."store_id") AND ("s"."owner_id" = ( SELECT "auth"."uid"() AS "uid")))))) WITH CHECK ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "print_jobs"."store_id") AND ("s"."owner_id" = ( SELECT "auth"."uid"() AS "uid"))))));

-- public.store_ownership_transfers
DROP POLICY IF EXISTS "store_ownership_transfers_admin_select" ON "public"."store_ownership_transfers";
CREATE POLICY "store_ownership_transfers_admin_select" ON "public"."store_ownership_transfers" FOR SELECT TO "authenticated" USING ("public"."is_admin"());

-- public.store_ratings
DROP POLICY IF EXISTS "store_ratings_insert_customer" ON "public"."store_ratings";
CREATE POLICY "store_ratings_insert_customer" ON "public"."store_ratings" FOR INSERT TO "authenticated" WITH CHECK ((("customer_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1 FROM "public"."orders" "o" WHERE (("o"."id" = "store_ratings"."order_id") AND ("o"."customer_id" = "auth"."uid"()) AND ("o"."store_id" = "store_ratings"."store_id") AND ("o"."status" = 'delivered'::"public"."order_status"))))));

-- public.store_ratings
DROP POLICY IF EXISTS "store_ratings_select_participants" ON "public"."store_ratings";
CREATE POLICY "store_ratings_select_participants" ON "public"."store_ratings" FOR SELECT TO "authenticated" USING ((("customer_id" = "auth"."uid"()) OR "public"."is_admin"() OR (EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "store_ratings"."store_id") AND ("s"."owner_id" = "auth"."uid"()))))));

-- public.store_settings
DROP POLICY IF EXISTS "store_settings_admin" ON "public"."store_settings";
CREATE POLICY "store_settings_admin" ON "public"."store_settings" TO "authenticated" USING ("public"."is_admin"()) WITH CHECK ("public"."is_admin"());

-- public.store_settings
DROP POLICY IF EXISTS "store_settings_select_owner" ON "public"."store_settings";
CREATE POLICY "store_settings_select_owner" ON "public"."store_settings" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "store_settings"."store_id") AND ("s"."owner_id" = "auth"."uid"())))));

-- public.store_settings
DROP POLICY IF EXISTS "store_settings_select_public" ON "public"."store_settings";
CREATE POLICY "store_settings_select_public" ON "public"."store_settings" FOR SELECT TO "authenticated", "anon" USING ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "store_settings"."store_id") AND ("s"."is_active" = true)))));

-- public.store_settings
DROP POLICY IF EXISTS "store_settings_update_owner" ON "public"."store_settings";
CREATE POLICY "store_settings_update_owner" ON "public"."store_settings" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "store_settings"."store_id") AND ("s"."owner_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1 FROM "public"."stores" "s" WHERE (("s"."id" = "store_settings"."store_id") AND ("s"."owner_id" = "auth"."uid"())))));

-- public.stores
DROP POLICY IF EXISTS "stores_insert_owner" ON "public"."stores";
CREATE POLICY "stores_insert_owner" ON "public"."stores" FOR INSERT TO "authenticated" WITH CHECK ((("owner_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1 FROM "public"."profiles" WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'store_owner'::"public"."user_role") AND "profiles"."is_active")))));

-- public.stores
DROP POLICY IF EXISTS "stores_select_active" ON "public"."stores";
CREATE POLICY "stores_select_active" ON "public"."stores" FOR SELECT TO "authenticated", "anon" USING (("is_active" = true));

-- public.stores
DROP POLICY IF EXISTS "stores_select_admin" ON "public"."stores";
CREATE POLICY "stores_select_admin" ON "public"."stores" FOR SELECT TO "authenticated" USING ("public"."is_admin"());

-- public.stores
DROP POLICY IF EXISTS "stores_select_owner" ON "public"."stores";
CREATE POLICY "stores_select_owner" ON "public"."stores" FOR SELECT TO "authenticated" USING (("owner_id" = "auth"."uid"()));

-- public.stores
DROP POLICY IF EXISTS "stores_update_admin" ON "public"."stores";
CREATE POLICY "stores_update_admin" ON "public"."stores" FOR UPDATE TO "authenticated" USING ("public"."is_admin"()) WITH CHECK ("public"."is_admin"());

-- public.stores
DROP POLICY IF EXISTS "stores_update_owner" ON "public"."stores";
CREATE POLICY "stores_update_owner" ON "public"."stores" FOR UPDATE TO "authenticated" USING (("owner_id" = "auth"."uid"())) WITH CHECK (("owner_id" = "auth"."uid"()));

-- public.user_fcm_tokens
DROP POLICY IF EXISTS "users_delete_own_fcm_tokens" ON "public"."user_fcm_tokens";
CREATE POLICY "users_delete_own_fcm_tokens" ON "public"."user_fcm_tokens" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));

-- public.user_fcm_tokens
DROP POLICY IF EXISTS "users_insert_own_fcm_tokens" ON "public"."user_fcm_tokens";
CREATE POLICY "users_insert_own_fcm_tokens" ON "public"."user_fcm_tokens" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));

-- public.user_fcm_tokens
DROP POLICY IF EXISTS "users_select_own_fcm_tokens" ON "public"."user_fcm_tokens";
CREATE POLICY "users_select_own_fcm_tokens" ON "public"."user_fcm_tokens" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));

-- public.user_fcm_tokens
DROP POLICY IF EXISTS "users_update_own_fcm_tokens" ON "public"."user_fcm_tokens";
CREATE POLICY "users_update_own_fcm_tokens" ON "public"."user_fcm_tokens" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));

-- ============================================================
-- SECTION 3 --- Least privilege on tables
--
-- anon previously held GRANT ALL on 28 tables (sync_local_privileges.sql).
-- RLS already blocked those reads, but the grants were a latent hazard:
-- disabling RLS or adding a permissive policy would have exposed
-- orders / profiles / payments to the public API key that ships inside
-- the APK. anon is now limited to SELECT on the public catalog only.
-- ============================================================

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;

-- Prevent future tables and sequences from inheriting anon privileges.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon;

-- The public catalog stays readable before sign-in (browsing stores/products).
GRANT SELECT ON TABLE "public"."products" TO anon;
GRANT SELECT ON TABLE "public"."product_categories" TO anon;
GRANT SELECT ON TABLE "public"."product_pricing" TO anon;
GRANT SELECT ON TABLE "public"."store_categories" TO anon;
GRANT SELECT ON TABLE "public"."store_settings" TO anon;
GRANT SELECT ON TABLE "public"."stores" TO anon;
GRANT SELECT ON TABLE "public"."offers" TO anon;

-- ============================================================
-- SECTION 4 --- Close the account-enumeration hole
--
-- lookup_profile_by_phone() is SECURITY DEFINER and returned
-- email + phone + full_name + role for ANY phone number, and it was
-- executable by `anon` (the public key ships inside the APK).
--
-- It is still needed before sign-in, so it is replaced by two boolean
-- functions that never return personal data:
--   verify_account_phone_email(phone, email) -> boolean
--       true only when BOTH the phone and the email belong to the same
--       active account. A wrong email and an unknown phone are
--       indistinguishable, so it cannot be used to enumerate users.
--   phone_exists(phone) -> boolean
--       existence only, used by the registration screen.
-- ============================================================

CREATE OR REPLACE FUNCTION public.verify_account_phone_email(
  p_phone text,
  p_email text
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $function$
  WITH input AS (
    SELECT
      nullif(
        replace(replace(replace(replace(trim(coalesce(p_phone, '')), ' ', ''), '-', ''), '(', ''), ')', ''),
        ''
      ) AS raw_phone,
      nullif(trim(coalesce(p_email, '')), '') AS raw_email
  ),
  normalized AS (
    SELECT
      CASE
        WHEN raw_phone IS NULL THEN NULL
        WHEN left(raw_phone, 2) = '00' THEN '+' || substr(raw_phone, 3)
        WHEN left(raw_phone, 2) = '20' THEN '+' || raw_phone
        WHEN left(raw_phone, 1) = '0'  THEN '+20' || substr(raw_phone, 2)
        ELSE '+' || raw_phone
      END AS phone,
      lower(raw_email) AS email
    FROM input
  )
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    JOIN normalized n ON p.phone = n.phone
    WHERE lower(coalesce(p.email, '')) = n.email
      AND p.is_active = true
  );
$function$;

COMMENT ON FUNCTION public.verify_account_phone_email(text, text) IS
  'Pre-authentication check: true only when the phone AND email belong to the same active account. Returns no personal data.';

CREATE OR REPLACE FUNCTION public.phone_exists(
  p_phone text
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $function$
  WITH input AS (
    SELECT
      nullif(
        replace(replace(replace(replace(trim(coalesce(p_phone, '')), ' ', ''), '-', ''), '(', ''), ')', ''),
        ''
      ) AS raw_phone
  ),
  normalized AS (
    SELECT
      CASE
        WHEN raw_phone IS NULL THEN NULL
        WHEN left(raw_phone, 2) = '00' THEN '+' || substr(raw_phone, 3)
        WHEN left(raw_phone, 2) = '20' THEN '+' || raw_phone
        WHEN left(raw_phone, 1) = '0'  THEN '+20' || substr(raw_phone, 2)
        ELSE '+' || raw_phone
      END AS phone
    FROM input
  )
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    JOIN normalized n ON p.phone = n.phone
  );
$function$;

COMMENT ON FUNCTION public.phone_exists(text) IS
  'Registration helper: whether a phone number already has an account. Returns no personal data.';

-- The PII-returning lookup is no longer callable by the public key.
REVOKE EXECUTE ON FUNCTION public.lookup_profile_by_phone(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.lookup_profile_by_phone(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.lookup_profile_by_phone(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lookup_profile_by_phone(text) TO service_role;

-- The two boolean replacements stay reachable pre-authentication.
GRANT EXECUTE ON FUNCTION public.verify_account_phone_email(text, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.phone_exists(text) TO anon, authenticated, service_role;

-- ============================================================
-- SECTION 5 --- Least privilege on function execution
--
-- Functions were executable by PUBLIC (hence by anon). The privileged
-- ones carry internal guards (is_admin() / auth.uid()), so they were not
-- directly exploitable, but anon should never be able to attempt them.
-- Only a small read-only whitelist stays available to anon.
-- ============================================================

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

-- Authenticated users and the service role keep full function access.
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- Trigger helpers invoked by Supabase Auth internals.
DO $block$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    EXECUTE 'GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO supabase_auth_admin';
  END IF;
END;
$block$;

-- anon whitelist: caller-scoped helpers and public configuration only.
GRANT EXECUTE ON FUNCTION public.current_user_role() TO anon;
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon;
GRANT EXECUTE ON FUNCTION public.get_delivery_settings() TO anon;
GRANT EXECUTE ON FUNCTION public.calculate_delivery_fee(integer) TO anon;
GRANT EXECUTE ON FUNCTION public.calculate_delivery_area_surcharge(text) TO anon;
GRANT EXECUTE ON FUNCTION public.verify_account_phone_email(text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.phone_exists(text) TO anon;

-- Prevent future functions from becoming world-executable.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- ============================================================
-- SECTION 6 --- Verification assertions
-- ============================================================

DO $verify$
DECLARE
  v_missing_tables text;
  v_anon_tables text;
  v_missing_policies text;
BEGIN
  -- 1. every public table must have RLS enabled
  SELECT string_agg(c.relname, ', ') INTO v_missing_tables
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind = 'r'
    AND NOT c.relrowsecurity;

  IF v_missing_tables IS NOT NULL THEN
    RAISE EXCEPTION 'RLS still disabled on: %', v_missing_tables;
  END IF;

  -- 2. anon must hold no write privilege on sensitive tables
  SELECT string_agg(c.relname, ', ') INTO v_anon_tables
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind = 'r'
    AND (
      has_table_privilege('anon', c.oid, 'INSERT')
      OR has_table_privilege('anon', c.oid, 'UPDATE')
      OR has_table_privilege('anon', c.oid, 'DELETE')
      OR has_table_privilege('anon', c.oid, 'TRUNCATE')
    )
    AND c.relname IN (
      'orders', 'order_items', 'profiles', 'addresses', 'payments',
      'payment_proofs', 'user_fcm_tokens', 'user_passwords',
      'notifications', 'driver_ratings', 'driver_rejections'
    );

  IF v_anon_tables IS NOT NULL THEN
    RAISE EXCEPTION 'anon still has write privileges on: %', v_anon_tables;
  END IF;

  -- 3. the PII-returning lookup must not be executable by anon
  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'lookup_profile_by_phone'
      AND has_function_privilege('anon', p.oid, 'EXECUTE')
  ) THEN
    RAISE EXCEPTION 'lookup_profile_by_phone is still executable by anon';
  END IF;

  -- 3b. the boolean replacements MUST stay executable by anon
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'verify_account_phone_email'
      AND has_function_privilege('anon', p.oid, 'EXECUTE')
  ) OR NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'phone_exists'
      AND has_function_privilege('anon', p.oid, 'EXECUTE')
  ) THEN
    RAISE EXCEPTION 'boolean replacement functions are not executable by anon';
  END IF;

  -- 4. the boolean replacements must exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'verify_account_phone_email'
  ) OR NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'phone_exists'
  ) THEN
    RAISE EXCEPTION 'boolean replacement functions are missing';
  END IF;

  -- 5. the critical business policies must still be present
  SELECT string_agg(expected, ', ') INTO v_missing_policies
  FROM unnest(ARRAY[
    'orders_select_customer', 'orders_select_driver', 'orders_select_store_owner',
    'orders_select_admin', 'profiles_select_own', 'profiles_select_admin',
    'addresses_select_own', 'payments_select_customer',
    'driver_ratings_select_participants', 'driver_rejections_select_own'
  ]) AS expected
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = expected
  );

  IF v_missing_policies IS NOT NULL THEN
    RAISE EXCEPTION 'critical policies missing: %', v_missing_policies;
  END IF;

  RAISE NOTICE 'Phase 1 security hardening verified successfully.';
END;
$verify$;

COMMIT;
