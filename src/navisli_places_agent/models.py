from __future__ import annotations

from datetime import date
from typing import Any, Literal

from pydantic import BaseModel, EmailStr, Field, HttpUrl, field_validator

VerificationStatus = Literal["verified", "review_required", "unverified"]
PlaceStatus = Literal["active", "inactive", "temporarily_closed", "archived"]


class PlaceInput(BaseModel):
    public_reference: str = Field(min_length=3, max_length=40)
    name: str = Field(min_length=1, max_length=255)
    primary_category: str = Field(min_length=1, max_length=100)
    subcategory: str = Field(min_length=1, max_length=100)
    address_line_1: str | None = None
    postal_area: str | None = None
    eircode: str | None = None
    phone: str | None = None
    email: EmailStr | None = None
    website_url: HttpUrl | None = None
    description: str | None = None
    status: PlaceStatus = "active"
    source_type: str = Field(min_length=1, max_length=100)
    verification_status: VerificationStatus = "unverified"
    source_name: str = Field(min_length=1, max_length=255)
    source_url: HttpUrl
    retrieved_date: date
    review_notes: str | None = None

    @field_validator(
        "address_line_1",
        "postal_area",
        "eircode",
        "phone",
        "email",
        "website_url",
        "description",
        "review_notes",
        mode="before",
    )
    @classmethod
    def blank_optional_values_to_none(cls, value: Any) -> Any:
        if isinstance(value, str) and not value.strip():
            return None
        return value

    @field_validator("public_reference", "primary_category", "subcategory", "source_type")
    @classmethod
    def strip_required(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("must not be blank")
        return value

    def to_supabase(self) -> dict[str, object]:
        data = self.model_dump(mode="json")
        if data.get("website_url") is not None:
            data["website_url"] = str(data["website_url"])
        data["source_url"] = str(data["source_url"])
        return data
