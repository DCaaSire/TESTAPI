# NaviSlí Places Data Agent

A supervised Python interconnector that validates place CSV files, checks Supabase for duplicate records, inserts safe records, routes uncertain records to a review queue, and preserves data lineage.

## Safety model

- Dry-run is the default.
- Existing `public_reference` values are never overwritten automatically.
- Likely duplicates are sent to `place_review_queue`.
- Every accepted place receives a `place_lineage` record.
- No web scraping or external AI API is used in this initial release.

## Setup

1. Use Python 3.12.
2. Create and activate a virtual environment.
3. Install the package:

```bash
pip install -e ".[dev]"
```

4. Run `supabase/agent_tables.sql` in the Supabase SQL Editor.
5. Copy `.env.example` to `.env` and add the Supabase project URL and service-role key.

Never commit `.env` or expose the service-role key in browser code.

## Validate a CSV without writing

```bash
navisli-places import-csv data/navisli_places.csv \
  --source-name "NaviSlí starter dataset" \
  --dry-run
```

## Import into Supabase

```bash
navisli-places import-csv data/navisli_places.csv \
  --source-name "NaviSlí starter dataset" \
  --write
```

## Tests

```bash
pytest
ruff check .
```

## Next work packages

1. Add detailed rejection reports.
2. Add GeoJSON and DLR open-data connectors.
3. Add coordinate validation and permitted-area controls.
4. Add a controlled review and approval interface.
5. Publish Cormorant AI events after the event contract is agreed.
