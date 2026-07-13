from __future__ import annotations

import csv
from dataclasses import dataclass, field
from pathlib import Path

from pydantic import ValidationError

from .duplicate import compare_place
from .models import PlaceInput
from .repository import PlacesRepository


@dataclass
class ImportSummary:
    received: int = 0
    created: int = 0
    updated: int = 0
    rejected: int = 0
    review: int = 0
    validation_errors: list[dict[str, object]] = field(default_factory=list)


def import_csv(
    path: Path,
    repository: PlacesRepository | None,
    source_name: str,
    dry_run: bool = True,
) -> ImportSummary:
    summary = ImportSummary()
    batch_id: str | None = None
    if not dry_run:
        if repository is None:
            raise ValueError("repository is required when dry_run is false")
        batch_id = repository.create_import_batch(path.name, source_name)

    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        for row_number, row in enumerate(csv.DictReader(handle), start=2):
            summary.received += 1
            try:
                place = PlaceInput.model_validate(row)
            except ValidationError as exc:
                summary.rejected += 1
                summary.validation_errors.append(
                    {
                        "row": row_number,
                        "public_reference": row.get("public_reference"),
                        "errors": exc.errors(include_url=False, include_input=False),
                    }
                )
                continue

            if dry_run:
                continue

            assert repository is not None and batch_id is not None
            existing = repository.find_by_reference(place.public_reference)
            if existing:
                repository.queue_review(
                    batch_id,
                    place,
                    "public_reference already exists, automatic overwrite is disabled",
                    1.0,
                    str(existing["id"]),
                )
                summary.review += 1
                continue

            duplicate = None
            duplicate_record = None
            for candidate in repository.find_duplicate_candidates(place):
                decision = compare_place(place, candidate)
                if decision.likely_duplicate:
                    duplicate = decision
                    duplicate_record = candidate
                    break

            if duplicate and duplicate_record:
                repository.queue_review(
                    batch_id,
                    place,
                    duplicate.reason,
                    duplicate.confidence,
                    str(duplicate_record["id"]),
                )
                summary.review += 1
                continue

            created = repository.insert_place(place)
            repository.write_lineage(batch_id, str(created["id"]), place)
            summary.created += 1

    if not dry_run and repository and batch_id:
        repository.update_import_batch(
            batch_id,
            records_received=summary.received,
            records_created=summary.created,
            records_updated=summary.updated,
            records_rejected=summary.rejected,
            status="completed",
        )
    return summary
