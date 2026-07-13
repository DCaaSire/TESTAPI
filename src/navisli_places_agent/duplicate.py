from dataclasses import dataclass
from difflib import SequenceMatcher

from .models import PlaceInput
from .normalise import normalise_eircode, normalise_text


@dataclass(frozen=True)
class DuplicateDecision:
    likely_duplicate: bool
    confidence: float
    reason: str


def compare_place(candidate: PlaceInput, existing: dict[str, object]) -> DuplicateDecision:
    candidate_name = normalise_text(candidate.name)
    existing_name = normalise_text(str(existing.get("name") or ""))
    name_score = SequenceMatcher(None, candidate_name, existing_name).ratio()

    candidate_eircode = normalise_eircode(candidate.eircode)
    existing_eircode = normalise_eircode(str(existing.get("eircode") or ""))
    eircode_match = bool(candidate_eircode and candidate_eircode == existing_eircode)

    candidate_address = normalise_text(candidate.address_line_1)
    existing_address = normalise_text(str(existing.get("address_line_1") or ""))
    address_score = SequenceMatcher(None, candidate_address, existing_address).ratio()

    if eircode_match and name_score >= 0.65:
        return DuplicateDecision(True, max(0.9, name_score), "matching Eircode and similar name")
    if name_score >= 0.92 and address_score >= 0.75:
        return DuplicateDecision(True, min(0.99, (name_score + address_score) / 2), "similar name and address")
    return DuplicateDecision(False, max(name_score, address_score), "no strong duplicate signal")
