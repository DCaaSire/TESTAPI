# NaviSlí Places Data Agent Instructions

## Purpose
Build a supervised data interconnector that validates place records, detects duplicates, writes safe records to Supabase, and routes uncertain records to review.

## Rules
- Use Python 3.12.
- Never commit secrets.
- Never overwrite a verified place automatically.
- Preserve source attribution and lineage for every accepted record.
- Support dry-run mode for all imports.
- Do not add web scraping or external AI API calls in the initial build.
- Keep transformations deterministic and covered by tests.
- Use commas rather than em dashes in documentation.
