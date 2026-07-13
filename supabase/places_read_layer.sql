-- NaviSlí controlled Places read layer
-- Run once in the Supabase SQL Editor after the core places schema.

create extension if not exists pg_trgm;

create index if not exists places_name_trgm_idx
    on public.places using gin (name gin_trgm_ops);

create index if not exists places_category_idx
    on public.places (primary_category);

create index if not exists places_postal_area_idx
    on public.places (postal_area);

create index if not exists places_status_idx
    on public.places (status);

create or replace function public.search_places(
    p_query text default null,
    p_category text default null,
    p_area text default null,
    p_limit integer default 10
)
returns table (
    public_reference text,
    name text,
    primary_category text,
    subcategory text,
    address_line_1 text,
    postal_area text,
    eircode text,
    phone text,
    email text,
    website_url text,
    description text,
    verification_status text,
    relevance_score real
)
language sql
stable
security definer
set search_path = public
as $$
    select
        p.public_reference,
        p.name,
        p.primary_category,
        p.subcategory,
        p.address_line_1,
        p.postal_area,
        p.eircode,
        p.phone,
        p.email,
        p.website_url,
        p.description,
        p.verification_status,
        case
            when nullif(trim(p_query), '') is null then 1.0::real
            else greatest(
                similarity(lower(p.name), lower(trim(p_query))),
                similarity(lower(coalesce(p.description, '')), lower(trim(p_query))),
                case when lower(p.name) like '%' || lower(trim(p_query)) || '%' then 1.0 else 0.0 end,
                case when lower(coalesce(p.primary_category, '')) like '%' || lower(trim(p_query)) || '%' then 0.8 else 0.0 end,
                case when lower(coalesce(p.subcategory, '')) like '%' || lower(trim(p_query)) || '%' then 0.8 else 0.0 end,
                case when lower(coalesce(p.postal_area, '')) like '%' || lower(trim(p_query)) || '%' then 0.7 else 0.0 end,
                case when lower(coalesce(p.address_line_1, '')) like '%' || lower(trim(p_query)) || '%' then 0.7 else 0.0 end
            )::real
        end as relevance_score
    from public.places p
    where p.status = 'active'
      and (
          nullif(trim(p_category), '') is null
          or lower(p.primary_category) = lower(trim(p_category))
          or lower(coalesce(p.subcategory, '')) = lower(trim(p_category))
      )
      and (
          nullif(trim(p_area), '') is null
          or lower(coalesce(p.postal_area, '')) like '%' || lower(trim(p_area)) || '%'
          or lower(coalesce(p.address_line_1, '')) like '%' || lower(trim(p_area)) || '%'
          or lower(coalesce(p.eircode, '')) like '%' || lower(trim(p_area)) || '%'
      )
      and (
          nullif(trim(p_query), '') is null
          or lower(p.name) like '%' || lower(trim(p_query)) || '%'
          or lower(coalesce(p.description, '')) like '%' || lower(trim(p_query)) || '%'
          or lower(coalesce(p.primary_category, '')) like '%' || lower(trim(p_query)) || '%'
          or lower(coalesce(p.subcategory, '')) like '%' || lower(trim(p_query)) || '%'
          or lower(coalesce(p.postal_area, '')) like '%' || lower(trim(p_query)) || '%'
          or lower(coalesce(p.address_line_1, '')) like '%' || lower(trim(p_query)) || '%'
          or similarity(lower(p.name), lower(trim(p_query))) >= 0.25
      )
    order by relevance_score desc, p.name asc
    limit least(greatest(coalesce(p_limit, 10), 1), 50);
$$;

create or replace function public.get_place_by_reference(
    p_public_reference text
)
returns table (
    public_reference text,
    name text,
    primary_category text,
    subcategory text,
    address_line_1 text,
    postal_area text,
    eircode text,
    phone text,
    email text,
    website_url text,
    description text,
    verification_status text,
    source_name text,
    source_url text,
    retrieved_date date
)
language sql
stable
security definer
set search_path = public
as $$
    select
        p.public_reference,
        p.name,
        p.primary_category,
        p.subcategory,
        p.address_line_1,
        p.postal_area,
        p.eircode,
        p.phone,
        p.email,
        p.website_url,
        p.description,
        p.verification_status,
        p.source_name,
        p.source_url,
        p.retrieved_date
    from public.places p
    where p.status = 'active'
      and p.public_reference = trim(p_public_reference)
    limit 1;
$$;

revoke all on function public.search_places(text, text, text, integer) from public;
revoke all on function public.get_place_by_reference(text) from public;

grant execute on function public.search_places(text, text, text, integer) to anon, authenticated, service_role;
grant execute on function public.get_place_by_reference(text) to anon, authenticated, service_role;
