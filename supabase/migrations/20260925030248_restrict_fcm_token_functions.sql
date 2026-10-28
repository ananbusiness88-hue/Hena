revoke execute
on function public.register_fcm_token(text, text)
from public, anon, service_role;

revoke execute
on function public.unregister_fcm_token(text)
from public, anon, service_role;

grant execute
on function public.register_fcm_token(text, text)
to authenticated;

grant execute
on function public.unregister_fcm_token(text)
to authenticated;