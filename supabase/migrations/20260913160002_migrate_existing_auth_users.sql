BEGIN;

-- ============================================================
-- HENA AUTH MIGRATION DRY RUN
-- Preserve original auth.users / identities / profiles
-- ============================================================

--
-- PostgreSQL database dump
--

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at, recovery_token, recovery_sent_at, email_change_token_new, email_change, email_change_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at, phone, phone_confirmed_at, phone_change, phone_change_token, phone_change_sent_at, email_change_token_current, email_change_confirm_status, banned_until, reauthentication_token, reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous) VALUES ('00000000-0000-0000-0000-000000000000', '97266c15-2e07-4d49-b96c-91172c471db6', 'authenticated', 'authenticated', 'yassinmankingenan@gmail.com', '$2a$10$W98ZK2M2eIg2Vs9/JfHoEuG/FhBPon/a2V5ZEsMmuzF.VRbbFo2OG', '2026-09-04 01:17:13.100772+00', NULL, '', '2026-09-04 01:17:00.454166+00', '', '2026-09-13 08:19:40.412258+00', '', '', NULL, '2026-09-13 08:19:55.224299+00', '{"provider": "email", "providers": ["email"]}', '{"sub": "97266c15-2e07-4d49-b96c-91172c471db6", "email": "yassinmankingenan@gmail.com", "phone": "+201098765432", "full_name": "محمد محمود محمد", "email_verified": true, "phone_verified": false}', NULL, '2026-09-04 01:17:00.319812+00', '2026-09-13 09:19:31.468732+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false);
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at, recovery_token, recovery_sent_at, email_change_token_new, email_change, email_change_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at, phone, phone_confirmed_at, phone_change, phone_change_token, phone_change_sent_at, email_change_token_current, email_change_confirm_status, banned_until, reauthentication_token, reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous) VALUES ('00000000-0000-0000-0000-000000000000', '89c03a1e-b825-4b3a-b855-8e5a1ceb9dab', 'authenticated', 'authenticated', 'directorahmed88@gmail.com', '$2a$10$o23dLAtMy2FYSgRJlK9Xlu8MvWXrGc7HPOeejuQ08ye46F2DpMMj2', '2026-08-31 01:40:49.960263+00', NULL, '', '2026-08-31 01:40:38.04253+00', '', '2026-09-11 02:43:57.614724+00', '', '', NULL, '2026-09-11 02:44:10.651408+00', '{"provider": "email", "providers": ["email"]}', '{"sub": "89c03a1e-b825-4b3a-b855-8e5a1ceb9dab", "email": "directorahmed88@gmail.com", "phone": "+201559880944", "full_name": "Yassin Ahmed anan", "email_verified": true, "phone_verified": false}', NULL, '2026-08-31 01:40:37.955957+00', '2026-09-11 02:44:10.668465+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false);
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at, recovery_token, recovery_sent_at, email_change_token_new, email_change, email_change_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at, phone, phone_confirmed_at, phone_change, phone_change_token, phone_change_sent_at, email_change_token_current, email_change_confirm_status, banned_until, reauthentication_token, reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous) VALUES ('00000000-0000-0000-0000-000000000000', 'c7bfb164-0af2-435f-9eb0-baaa9b19f65a', 'authenticated', 'authenticated', 'anan.business88@gmail.com', '$2a$10$JHD9Qo8mi5UB/wLib/NobOo4jcULzWrm59DOgbcojul6h368zM/4K', '2026-08-30 22:12:18.139456+00', NULL, '', '2026-08-30 22:12:01.620501+00', '', '2026-09-11 04:59:36.13838+00', '', '', NULL, '2026-09-11 04:59:53.433253+00', '{"provider": "email", "providers": ["email"]}', '{"sub": "c7bfb164-0af2-435f-9eb0-baaa9b19f65a", "email": "anan.business88@gmail.com", "phone": "+201002026939", "full_name": "Ahmed Anan Anan", "email_verified": true, "phone_verified": false}', NULL, '2026-08-30 22:12:01.553051+00', '2026-09-11 04:59:53.458284+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false);


--
-- PostgreSQL database dump complete
--



--
-- PostgreSQL database dump
--

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, id) VALUES ('c7bfb164-0af2-435f-9eb0-baaa9b19f65a', 'c7bfb164-0af2-435f-9eb0-baaa9b19f65a', '{"sub": "c7bfb164-0af2-435f-9eb0-baaa9b19f65a", "email": "anan.business88@gmail.com", "phone": "+201002026939", "full_name": "Ahmed Anan Anan", "email_verified": true, "phone_verified": false}', 'email', '2026-08-30 22:12:01.599262+00', '2026-08-30 22:12:01.599354+00', '2026-08-30 22:12:01.599354+00', 'df17d25b-fa28-423e-8ab4-8e6b96377395');
INSERT INTO auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, id) VALUES ('89c03a1e-b825-4b3a-b855-8e5a1ceb9dab', '89c03a1e-b825-4b3a-b855-8e5a1ceb9dab', '{"sub": "89c03a1e-b825-4b3a-b855-8e5a1ceb9dab", "email": "directorahmed88@gmail.com", "phone": "+201559880944", "full_name": "Yassin Ahmed anan", "email_verified": true, "phone_verified": false}', 'email', '2026-08-31 01:40:38.013057+00', '2026-08-31 01:40:38.013352+00', '2026-08-31 01:40:38.013352+00', '474dfcbe-c4fd-4869-8da3-347b6ac9d234');
INSERT INTO auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, id) VALUES ('97266c15-2e07-4d49-b96c-91172c471db6', '97266c15-2e07-4d49-b96c-91172c471db6', '{"sub": "97266c15-2e07-4d49-b96c-91172c471db6", "email": "yassinmankingenan@gmail.com", "phone": "+201098765432", "full_name": "محمد محمود محمد", "email_verified": true, "phone_verified": false}', 'email', '2026-09-04 01:17:00.417889+00', '2026-09-04 01:17:00.41807+00', '2026-09-04 01:17:00.41807+00', 'd9059ae1-23ee-4243-93b0-e1d0df0fc67f');


--
-- PostgreSQL database dump complete
--



-- handle_new_user() creates temporary customer profiles.
-- Remove those rows so the original Local profiles can be
-- inserted with their original roles.
DELETE FROM public.profiles
WHERE id IN (
  '97266c15-2e07-4d49-b96c-91172c471db6',
  '89c03a1e-b825-4b3a-b855-8e5a1ceb9dab',
  'c7bfb164-0af2-435f-9eb0-baaa9b19f65a'
);

--
-- PostgreSQL database dump
--

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: profiles; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.profiles (id, full_name, phone, email, role, avatar_url, is_active, created_at, updated_at) VALUES ('c7bfb164-0af2-435f-9eb0-baaa9b19f65a', 'Ahmed Anan Anan', '+201002026939', 'anan.business88@gmail.com', 'admin', NULL, true, '2026-08-30 22:12:01.551347+00', '2026-08-30 22:18:18.324112+00');
INSERT INTO public.profiles (id, full_name, phone, email, role, avatar_url, is_active, created_at, updated_at) VALUES ('89c03a1e-b825-4b3a-b855-8e5a1ceb9dab', 'Yassin Ahmed anan', '+201559880944', 'directorahmed88@gmail.com', 'store_owner', NULL, true, '2026-08-31 01:40:37.950716+00', '2026-08-31 02:59:49.083898+00');
INSERT INTO public.profiles (id, full_name, phone, email, role, avatar_url, is_active, created_at, updated_at) VALUES ('97266c15-2e07-4d49-b96c-91172c471db6', 'محمد محمود محمد', '+201098765432', 'yassinmankingenan@gmail.com', 'driver', NULL, true, '2026-09-04 01:17:00.316412+00', '2026-09-05 00:32:34.471271+00');


--
-- PostgreSQL database dump complete
--



SELECT
  (SELECT count(*)
   FROM auth.users
   WHERE id IN (
     '97266c15-2e07-4d49-b96c-91172c471db6',
     '89c03a1e-b825-4b3a-b855-8e5a1ceb9dab',
     'c7bfb164-0af2-435f-9eb0-baaa9b19f65a'
   )) AS users_count,

  (SELECT count(*)
   FROM auth.identities
   WHERE user_id IN (
     '97266c15-2e07-4d49-b96c-91172c471db6',
     '89c03a1e-b825-4b3a-b855-8e5a1ceb9dab',
     'c7bfb164-0af2-435f-9eb0-baaa9b19f65a'
   )) AS identities_count,

  (SELECT count(*)
   FROM public.profiles
   WHERE id IN (
     '97266c15-2e07-4d49-b96c-91172c471db6',
     '89c03a1e-b825-4b3a-b855-8e5a1ceb9dab',
     'c7bfb164-0af2-435f-9eb0-baaa9b19f65a'
   )) AS profiles_count,

  (SELECT count(*)
   FROM public.profiles
   WHERE id IN (
     '97266c15-2e07-4d49-b96c-91172c471db6',
     '89c03a1e-b825-4b3a-b855-8e5a1ceb9dab',
     'c7bfb164-0af2-435f-9eb0-baaa9b19f65a'
   )
   AND role IN ('admin', 'store_owner', 'driver')) AS correct_roles_count;

COMMIT;