from typing import Optional, List
from pydantic import BaseModel, EmailStr
from uuid import UUID
from datetime import datetime

class OrganizationBase(BaseModel):
    name: str
    business_type: str
    subdomain: Optional[str] = None
    owner_name: str
    phone_number: str

class OrganizationCreate(OrganizationBase):
    pass

class OrganizationUpdate(BaseModel):
    name: Optional[str] = None
    phone_number: Optional[str] = None
    plan: Optional[str] = None
    billing_status: Optional[str] = None

class OrganizationOut(OrganizationBase):
    id: UUID
    plan: str
    billing_status: str
    setup_fee_paid: bool
    license_key: Optional[str] = None
    trial_ends_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True
