from typing import Optional, Dict, Any
from pydantic import BaseModel
from uuid import UUID
from datetime import datetime

class MpesaStkPushRequest(BaseModel):
    organization_id: UUID
    phone_number: str  # Format: 2547XXXXXXXX or 07XXXXXXXX
    amount: float
    account_reference: str = "Setup Fee"
    transaction_desc: str = "Hirall POS Onboarding"

class MpesaStkPushResponse(BaseModel):
    success: bool
    checkout_request_id: str
    merchant_request_id: str
    customer_message: str
    response_code: str = "0"

class MpesaCallbackPayload(BaseModel):
    Body: Dict[str, Any]

class PaymentStatusCheck(BaseModel):
    organization_id: UUID
    checkout_request_id: Optional[str] = None
