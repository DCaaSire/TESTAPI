# NaviSlí Places Data Agent Instructions

## Scope
Build a supervised data interconnector for importing structured Places records into Supabase.

## Non-negotiable rules
- Never scrape or publish uncontrolled web data.
- Never overwrite a verified place automatically.
- Every accepted record must retain source attribution and lineage.
- Ambiguous, duplicate, conflicting, or low-confidence records go to the review queue.
- Supabase credentials must come from environment variables and must never be committed.
- Support dry-run mode for every import path.
- Add tests for validation, duplicate decisions, and import summaries.
- Prefer explicit deterministic rules over AI inference in the first release.

## Technical baseline
- Python 3.12
- Pydantic v2
- Typer CLI
- supabase-py
- pytest
- Ruff

## Definition of done
A change is complete only when tests pass, documentation is updated, errors are handled, and no secret or placeholder production logic is committed.
