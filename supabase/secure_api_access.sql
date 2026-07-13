-- NaviSlí secure API access hardening
-- Run after places_read_layer.sql and after the search-places Edge Function is ready.

revoke execute on function public.search_places(text, text, text, integer) from anon, authenticated;
revoke execute on function public.get_place_by_reference(text) from anon, authenticated;

grant execute on function public.search_places(text, text, text, integer) to service_role;
grant execute on function public.get_place_by_reference(text) to service_role;
