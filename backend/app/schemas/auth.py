from typing import Optional
from pydantic import BaseModel, EmailStr
from uuid import UUID

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    organization_id: str
    branch_id: Optional[str] = None
    role: str
    full_name: str
    email: str

class TokenPayload(BaseModel):
    sub: Optional[str] = None
    org_id: Optional[str] = None
    branch_id: Optional[str] = None
    role: Optional[str] = None

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class PinLoginRequest(BaseModel):
    organization_id: str
    branch_id: str
    pin_code: str

class RegisterOrgRequest(BaseModel):
    name: str
    business_type: str  # supermarket | retail | restaurant | bar_club | laundry | spa | car_wash
    owner_name: str
    phone_number: str
    email: EmailStr
    password: str
    country: str = "KE"
    primary_branch_name: str = "Main Branch"
    subdomain: Optional[str] = None

class LicenseVerificationRequest(BaseModel):
    license_key: str
    device_id: Optional[str] = None
    device_name: Optional[str] = None

class LicenseVerificationResponse(BaseModel):
    is_valid: bool
    organization_id: str
    organization_name: str
    business_type: str
    branch_id: str
    branch_name: str
    plan: str
    billing_status: str
    enabled_modules: list[str]
    powersync_token: Optional[str] = None
    powersync_url: Optional[str] = None
    message: Optional[str] = None

class UserCreate(BaseModel):
    email: EmailStr
    full_name: str
    password: str
    role: str
    branch_id: Optional[UUID] = None
    pin_code: Optional[str] = None

class UserOut(BaseModel):
    id: UUID
    organization_id: UUID
    branch_id: Optional[UUID] = None
    email: str
    full_name: str
    role: str
    pin_code: Optional[str] = None
    is_active: bool

    class Config:
        from_attributes = True
