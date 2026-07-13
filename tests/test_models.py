from datetime import date

import pytest
from pydantic import ValidationError

from navisli_places_agent.models import PlaceInput


def valid_place() -> dict[str, object]:
    return {
        "public_reference": "NAV-POI-000001",
        "name": "Sandyford Luas Stop",
        "primary_category": "transport_stop",
        "subcategory": "luas_stop",
        "source_type": "official_source",
        "verification_status": "verified",
        "source_name": "Luas",
        "source_url": "https://www.luas.ie/",
        "retrieved_date": date(2026, 7, 13),
    }


def test_valid_place() -> None:
    place = PlaceInput.model_validate(valid_place())
    assert place.public_reference == "NAV-POI-000001"


def test_rejects_missing_source() -> None:
    payload = valid_place()
    payload["source_name"] = ""
    with pytest.raises(ValidationError):
        PlaceInput.model_validate(payload)
