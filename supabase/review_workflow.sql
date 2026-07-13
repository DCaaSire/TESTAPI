-- NaviSlí controlled review workflow
-- Run this once in the Supabase SQL Editor after agent_tables.sql.

alter table public.place_review_queue
    add column if not exists resolution_action text,
    add column if not exists resolved_place_id uuid references public.places(id),
    add column if not exists reviewed_by_name text;

create or replace view public.pending_place_reviews as
select
    q.id as review_id,
    q.created_at,
    q.review_reason,
    q.confidence_score,
    q.proposed_public_reference,
    q.proposed_data ->> 'name' as proposed_name,
    q.proposed_data ->> 'primary_category' as proposed_category,
    q.proposed_data ->> 'subcategory' as proposed_subcategory,
    q.proposed_data ->> 'address_line_1' as proposed_address,
    q.proposed_data ->> 'eircode' as proposed_eircode,
    q.proposed_data ->> 'source_name' as source_name,
    q.proposed_data ->> 'source_url' as source_url,
    q.existing_place_id,
    p.public_reference as existing_public_reference,
    p.name as existing_name,
    p.address_line_1 as existing_address,
    p.eircode as existing_eircode,
    q.status
from public.place_review_queue q
left join public.places p on p.id = q.existing_place_id
where q.status = 'pending'
order by q.created_at asc;

create or replace function public.reject_place_review(
    p_review_id uuid,
    p_reviewer text,
    p_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    update public.place_review_queue
    set status = 'rejected',
        resolution_action = 'rejected',
        reviewed_by_name = p_reviewer,
        reviewed_at = now(),
        review_notes = p_notes
    where id = p_review_id
      and status = 'pending';

    if not found then
        raise exception 'Pending review % was not found', p_review_id;
    end if;
end;
$$;

create or replace function public.approve_place_review_as_new(
    p_review_id uuid,
    p_reviewer text,
    p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_review public.place_review_queue%rowtype;
    v_place_id uuid;
begin
    select * into v_review
    from public.place_review_queue
    where id = p_review_id
      and status = 'pending'
    for update;

    if not found then
        raise exception 'Pending review % was not found', p_review_id;
    end if;

    if exists (
        select 1 from public.places
        where public_reference = v_review.proposed_public_reference
    ) then
        raise exception 'Public reference % already exists. Use merge or reject.',
            v_review.proposed_public_reference;
    end if;

    insert into public.places (
        public_reference,
        name,
        primary_category,
        subcategory,
        address_line_1,
        postal_area,
        eircode,
        phone,
        email,
        website_url,
        description,
        status,
        source_type,
        verification_status,
        source_name,
        source_url,
        retrieved_date,
        review_notes
    ) values (
        v_review.proposed_data ->> 'public_reference',
        v_review.proposed_data ->> 'name',
        v_review.proposed_data ->> 'primary_category',
        v_review.proposed_data ->> 'subcategory',
        nullif(v_review.proposed_data ->> 'address_line_1', ''),
        nullif(v_review.proposed_data ->> 'postal_area', ''),
        nullif(v_review.proposed_data ->> 'eircode', ''),
        nullif(v_review.proposed_data ->> 'phone', ''),
        nullif(v_review.proposed_data ->> 'email', ''),
        nullif(v_review.proposed_data ->> 'website_url', ''),
        nullif(v_review.proposed_data ->> 'description', ''),
        coalesce(nullif(v_review.proposed_data ->> 'status', ''), 'active'),
        v_review.proposed_data ->> 'source_type',
        coalesce(nullif(v_review.proposed_data ->> 'verification_status', ''), 'unverified'),
        v_review.proposed_data ->> 'source_name',
        v_review.proposed_data ->> 'source_url',
        (v_review.proposed_data ->> 'retrieved_date')::date,
        nullif(v_review.proposed_data ->> 'review_notes', '')
    ) returning id into v_place_id;

    insert into public.place_lineage (
        place_id,
        import_batch_id,
        source_name,
        source_url,
        source_record_id,
        original_record,
        transformation_version
    ) values (
        v_place_id,
        v_review.import_batch_id,
        v_review.proposed_data ->> 'source_name',
        v_review.proposed_data ->> 'source_url',
        v_review.proposed_public_reference,
        v_review.proposed_data,
        'review-workflow-1.0'
    );

    update public.place_review_queue
    set status = 'approved',
        resolution_action = 'approved_as_new',
        resolved_place_id = v_place_id,
        reviewed_by_name = p_reviewer,
        reviewed_at = now(),
        review_notes = p_notes
    where id = p_review_id;

    return v_place_id;
end;
$$;

create or replace function public.merge_place_review_fill_blanks(
    p_review_id uuid,
    p_reviewer text,
    p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_review public.place_review_queue%rowtype;
    v_place_id uuid;
begin
    select * into v_review
    from public.place_review_queue
    where id = p_review_id
      and status = 'pending'
    for update;

    if not found then
        raise exception 'Pending review % was not found', p_review_id;
    end if;

    if v_review.existing_place_id is null then
        raise exception 'Review % has no existing place to merge into', p_review_id;
    end if;

    v_place_id := v_review.existing_place_id;

    update public.places
    set address_line_1 = coalesce(nullif(address_line_1, ''), nullif(v_review.proposed_data ->> 'address_line_1', '')),
        postal_area = coalesce(nullif(postal_area, ''), nullif(v_review.proposed_data ->> 'postal_area', '')),
        eircode = coalesce(nullif(eircode, ''), nullif(v_review.proposed_data ->> 'eircode', '')),
        phone = coalesce(nullif(phone, ''), nullif(v_review.proposed_data ->> 'phone', '')),
        email = coalesce(nullif(email, ''), nullif(v_review.proposed_data ->> 'email', '')),
        website_url = coalesce(nullif(website_url, ''), nullif(v_review.proposed_data ->> 'website_url', '')),
        description = coalesce(nullif(description, ''), nullif(v_review.proposed_data ->> 'description', '')),
        review_notes = coalesce(nullif(review_notes, ''), nullif(v_review.proposed_data ->> 'review_notes', ''))
    where id = v_place_id;

    insert into public.place_lineage (
        place_id,
        import_batch_id,
        source_name,
        source_url,
        source_record_id,
        original_record,
        transformation_version
    ) values (
        v_place_id,
        v_review.import_batch_id,
        v_review.proposed_data ->> 'source_name',
        v_review.proposed_data ->> 'source_url',
        v_review.proposed_public_reference,
        v_review.proposed_data,
        'review-fill-blanks-1.0'
    );

    update public.place_review_queue
    set status = 'approved',
        resolution_action = 'merged_fill_blanks',
        resolved_place_id = v_place_id,
        reviewed_by_name = p_reviewer,
        reviewed_at = now(),
        review_notes = p_notes
    where id = p_review_id;

    return v_place_id;
end;
$$;

revoke all on function public.reject_place_review(uuid, text, text) from public;
revoke all on function public.approve_place_review_as_new(uuid, text, text) from public;
revoke all on function public.merge_place_review_fill_blanks(uuid, text, text) from public;

grant execute on function public.reject_place_review(uuid, text, text) to service_role;
grant execute on function public.approve_place_review_as_new(uuid, text, text) to service_role;
grant execute on function public.merge_place_review_fill_blanks(uuid, text, text) to service_role;
