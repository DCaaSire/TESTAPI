from __future__ import annotations

from typing import Any

from supabase import Client

from .models import PlaceInput


class PlacesRepository:
    def __init__(self, client: Client) -> None:
        self.client = client

    def create_import_batch(self, source_file: str, source_name: str) -> str:
        response = self.client.table("import_batches").insert({
            "source_name": source_name,
            "source_type": "csv",
            "source_file": source_file,
            "status": "processing",
        }).execute()
        return str(response.data[0]["id"])

    def update_import_batch(self, batch_id: str, **values: Any) -> None:
        self.client.table("import_batches").update(values).eq("id", batch_id).execute()

    def find_by_reference(self, public_reference: str) -> dict[str, Any] | None:
        response = self.client.table("places").select("*").eq(
            "public_reference", public_reference
        ).limit(1).execute()
        return response.data[0] if response.data else None

    def find_duplicate_candidates(self, place: PlaceInput) -> list[dict[str, Any]]:
        query = self.client.table("places").select(
            "id,public_reference,name,address_line_1,eircode,verification_status"
        )
        if place.eircode:
            query = query.eq("eircode", place.eircode)
        else:
            query = query.ilike("name", f"%{place.name[:40]}%")
        return list(query.limit(20).execute().data or [])

    def insert_place(self, place: PlaceInput) -> dict[str, Any]:
        response = self.client.table("places").insert(place.to_supabase()).execute()
        return dict(response.data[0])

    def queue_review(
        self,
        batch_id: str,
        place: PlaceInput,
        reason: str,
        confidence: float,
        existing_place_id: str | None = None,
    ) -> None:
        self.client.table("place_review_queue").insert({
            "import_batch_id": batch_id,
            "proposed_public_reference": place.public_reference,
            "proposed_data": place.to_supabase(),
            "existing_place_id": existing_place_id,
            "review_reason": reason,
            "confidence_score": confidence,
            "status": "pending",
        }).execute()

    def write_lineage(self, batch_id: str, place_id: str, place: PlaceInput) -> None:
        self.client.table("place_lineage").insert({
            "place_id": place_id,
            "import_batch_id": batch_id,
            "source_name": place.source_name,
            "source_url": str(place.source_url),
            "source_record_id": place.public_reference,
            "original_record": place.to_supabase(),
            "transformation_version": "0.1.0",
        }).execute()
