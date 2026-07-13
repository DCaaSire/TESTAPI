from datetime import date

from navisli_places_agent.duplicate import compare_place
from navisli_places_agent.models import PlaceInput


def make_place(**changes: object) -> PlaceInput:
    payload = {
        "public_reference": "NAV-POI-000001",
        "name": "Beacon Hospital",
        "primary_category": "healthcare",
        "subcategory": "hospital",
        "address_line_1": "Beacon Court, Sandyford",
        "eircode": "D18 AK68",
        "source_type": "organisation_website",
        "verification_status": "verified",
        "source_name": "Beacon Hospital",
        "source_url": "https://www.beaconhospital.ie/",
        "retrieved_date": date(2026, 7, 13),
    }
    payload.update(changes)
    return PlaceInput.model_validate(payload)


def test_detects_matching_eircode_and_name() -> None:
    decision = compare_place(make_place(), {
        "name": "Beacon Hospital Dublin",
        "address_line_1": "Beacon Court",
        "eircode": "D18AK68",
    })
    assert decision.likely_duplicate is True


def test_allows_different_place() -> None:
    decision = compare_place(make_place(), {
        "name": "Sandyford Luas Stop",
        "address_line_1": "Blackthorn Avenue",
        "eircode": "",
    })
    assert decision.likely_duplicate is False
