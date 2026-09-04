from typing import Any
from uuid import UUID
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.orm import Session

from app.db.rls import get_db, set_tenant_context
from app.models.organization import Organization
from app.schemas.billing import (
    MpesaStkPushRequest,
    MpesaStkPushResponse,
    MpesaCallbackPayload
)
from app.services.mpesa import MpesaService

router = APIRouter()

@router.post("/mpesa-stk", response_model=MpesaStkPushResponse)
async def trigger_mpesa_stk_push(
    payload: MpesaStkPushRequest,
    db: Session = Depends(get_db)
) -> Any:
    """
    Triggers M-Pesa STK push for setup fee or subscription payment.
    """
    org = db.query(Organization).filter(Organization.id == payload.organization_id).first()
    if not org:
        raise HTTPException(status_code=404, detail="Organization not found.")

    res = await MpesaService.trigger_stk_push(
        phone_number=payload.phone_number,
        amount=payload.amount,
        account_reference=f"HIRALL-{str(org.id)[:6].upper()}",
        transaction_desc=payload.transaction_desc
    )

    if not res.get("success"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=res.get("CustomerMessage", "STK push could not be initiated.")
        )

    # In mock simulation, auto-mark setup fee as paid immediately for developer convenience
    if res.get("is_mock"):
        org.setup_fee_paid = True
        org.billing_status = "active"
        db.commit()

    return MpesaStkPushResponse(
        success=True,
        checkout_request_id=res.get("CheckoutRequestID", "mock_checkout_id"),
        merchant_request_id=res.get("MerchantRequestID", "mock_merchant_id"),
        customer_message=res.get("CustomerMessage", "Please check your phone to enter M-Pesa PIN."),
        response_code="0"
    )

@router.post("/mpesa-callback")
def mpesa_callback(
    payload: MpesaCallbackPayload,
    db: Session = Depends(get_db)
) -> Any:
    """
    Webhook callback handler from Safaricom Daraja / PayHero.
    """
    body = payload.Body.get("stkCallback", {})
    result_code = body.get("ResultCode")
    checkout_request_id = body.get("CheckoutRequestID")

    if result_code == 0:
        # Success: Parse metadata items
        callback_items = body.get("CallbackMetadata", {}).get("Item", [])
        amount = None
        receipt = None
        phone = None
        for item in callback_items:
            name = item.get("Name")
            val = item.get("Value")
            if name == "Amount":
                amount = val
            elif name == "MpesaReceiptNumber":
                receipt = val
            elif name == "PhoneNumber":
                phone = val

        # For production: find matching transaction and mark org setup_fee_paid = True
        # db.commit()

    return {"status": "received", "ResultCode": result_code}

@router.get("/status/{organization_id}")
def check_billing_status(
    organization_id: UUID,
    db: Session = Depends(get_db)
) -> Any:
    """
    Polls organization payment and activation status.
    """
    org = db.query(Organization).filter(Organization.id == organization_id).first()
    if not org:
        raise HTTPException(status_code=404, detail="Organization not found.")

    return {
        "organization_id": str(org.id),
        "setup_fee_paid": org.setup_fee_paid,
        "billing_status": org.billing_status,
        "plan": org.plan,
        "license_key": org.license_key,
        "trial_ends_at": org.trial_ends_at
    }
