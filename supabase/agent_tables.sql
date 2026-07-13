create table if not exists public.import_batches (
    id uuid primary key default gen_random_uuid(),
    source_name text not null,
    source_type text not null,
    source_file text,
    records_received integer default 0,
    records_created integer default 0,
    records_updated integer default 0,
    records_rejected integer default 0,
    status text not null default 'pending',
    started_at timestamptz default now(),
    completed_at timestamptz,
    error_message text
);

create table if not exists public.place_review_queue (
    id uuid primary key default gen_random_uuid(),
    import_batch_id uuid references public.import_batches(id),
    proposed_public_reference text,
    proposed_data jsonb not null,
    existing_place_id uuid references public.places(id),
    review_reason text not null,
    confidence_score numeric(5,4),
    status text not null default 'pending',
    reviewed_by uuid,
    reviewed_at timestamptz,
    review_notes text,
    created_at timestamptz default now()
);

create table if not exists public.place_lineage (
    id uuid primary key default gen_random_uuid(),
    place_id uuid references public.places(id),
    import_batch_id uuid references public.import_batches(id),
    source_name text not null,
    source_url text,
    source_record_id text,
    original_record jsonb,
    transformation_version text,
    created_at timestamptz default now()
);
