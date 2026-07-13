import re


def normalise_text(value: str | None) -> str:
    if not value:
        return ""
    value = value.casefold().strip()
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def normalise_eircode(value: str | None) -> str:
    return re.sub(r"\s+", "", (value or "").upper())
