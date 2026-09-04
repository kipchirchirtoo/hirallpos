import base64
import time
from datetime import datetime, timezone
import httpx
from typing import Dict, Any, Optional
from app.core.config import settings

class MpesaService:
    @staticmethod
    def format_phone_number(phone: str) -> str:
        """
        Normalizes Kenyan phone numbers to 254XXXXXXXXX format.
        """
        phone = phone.strip().replace(" ", "").replace("+", "")
        if phone.startswith("0"):
            return "254" + phone[1:]
        elif phone.startswith("7") or phone.startswith("1"):
            return "254" + phone
        return phone

    @staticmethod
    def generate_password(shortcode: str, passkey: str, timestamp: str) -> str:
        data_to_encode = f"{shortcode}{passkey}{timestamp}"
        return base64.b64encode(data_to_encode.encode()).decode("utf-8")

    @classmethod
    async def trigger_stk_push(
        cls,
        phone_number: str,
        amount: float,
        account_reference: str = "Hirall POS",
        transaction_desc: str = "POS Payment"
    ) -> Dict[str, Any]:
        formatted_phone = cls.format_phone_number(phone_number)
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
        
        # If in sandbox or mock credentials, simulate instant successful response
        if (
            settings.MPESA_ENVIRONMENT == "sandbox" 
            and (not settings.MPESA_CONSUMER_KEY or settings.MPESA_CONSUMER_KEY == "mock_consumer_key")
        ):
            checkout_id = f"ws_CO_{int(time.time())}_{formatted_phone[-4:]}"
            merchant_id = f"MCH_{int(time.time())}"
            return {
                "success": True,
                "MerchantRequestID": merchant_id,
                "CheckoutRequestID": checkout_id,
                "ResponseCode": "0",
                "ResponseDescription": "Success. Request accepted for processing",
                "CustomerMessage": f"Success. STK push simulated for {formatted_phone} (KES {amount:.2f}).",
                "is_mock": True
            }

        # Real Daraja API STK Push
        auth_url = (
            "https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials"
            if settings.MPESA_ENVIRONMENT == "sandbox"
            else "https://api.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials"
        )
        stk_url = (
            "https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest"
            if settings.MPESA_ENVIRONMENT == "sandbox"
            else "https://api.safaricom.co.ke/mpesa/stkpush/v1/processrequest"
        )

        try:
            auth_str = f"{settings.MPESA_CONSUMER_KEY}:{settings.MPESA_CONSUMER_SECRET}"
            encoded_auth = base64.b64encode(auth_str.encode()).decode("utf-8")
            
            async with httpx.AsyncClient(timeout=15.0) as client:
                token_resp = await client.get(
                    auth_url,
                    headers={"Authorization": f"Basic {encoded_auth}"}
                )
                token_resp.raise_for_status()
                access_token = token_resp.json().get("access_token")

                password = cls.generate_password(settings.MPESA_SHORTCODE, settings.MPESA_PASSKEY, timestamp)
                payload = {
                    "BusinessShortCode": settings.MPESA_SHORTCODE,
                    "Password": password,
                    "Timestamp": timestamp,
                    "TransactionType": "CustomerPayBillOnline",
                    "Amount": int(amount),
                    "PartyA": formatted_phone,
                    "PartyB": settings.MPESA_SHORTCODE,
                    "PhoneNumber": formatted_phone,
                    "CallBackURL": settings.MPESA_CALLBACK_URL,
                    "AccountReference": account_reference[:12],
                    "TransactionDesc": transaction_desc[:12]
                }

                stk_resp = await client.post(
                    stk_url,
                    json=payload,
                    headers={"Authorization": f"Bearer {access_token}"}
                )
                data = stk_resp.json()
                return {
                    "success": data.get("ResponseCode") == "0",
                    "MerchantRequestID": data.get("MerchantRequestID"),
                    "CheckoutRequestID": data.get("CheckoutRequestID"),
                    "ResponseCode": data.get("ResponseCode"),
                    "ResponseDescription": data.get("ResponseDescription"),
                    "CustomerMessage": data.get("CustomerMessage"),
                    "is_mock": False
                }
        except Exception as e:
            return {
                "success": False,
                "ResponseCode": "1",
                "CustomerMessage": f"Failed to initiate STK push: {str(e)}",
                "error": str(e)
            }
