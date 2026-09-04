import secrets
import string
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict, Any

class LicensingService:
    @staticmethod
    def generate_license_key() -> str:
        """
        Generates formatted license key: HPOS-XXXX-XXXX-XXXX
        """
        chars = string.ascii_uppercase + string.digits
        # Avoid ambiguous characters (0, O, 1, I)
        safe_chars = [c for c in chars if c not in "0O1I"]
        
        chunk1 = "".join(secrets.choice(safe_chars) for _ in range(4))
        chunk2 = "".join(secrets.choice(safe_chars) for _ in range(4))
        chunk3 = "".join(secrets.choice(safe_chars) for _ in range(4))
        
        return f"HPOS-{chunk1}-{chunk2}-{chunk3}"

    @staticmethod
    def calculate_trial_expiry(days: int = 14) -> datetime:
        return datetime.now(timezone.utc) + timedelta(days=days)

    @staticmethod
    def check_license_validity(
        billing_status: str,
        trial_ends_at: Optional[datetime],
        plan: str
    ) -> Dict[str, Any]:
        """
        Evaluates organization licensing status.
        Grace period policy: Does not hard lock mid-shift for lapsed payments.
        """
        now = datetime.now(timezone.utc)
        
        if plan in ["starter", "pro", "enterprise"] and billing_status == "active":
            return {
                "is_valid": True,
                "status": "active",
                "message": "Subscription active and in good standing."
            }

        if trial_ends_at:
            if now <= trial_ends_at:
                days_left = (trial_ends_at - now).days
                return {
                    "is_valid": True,
                    "status": "trial",
                    "days_left": days_left,
                    "message": f"Free trial active ({days_left} days remaining)."
                }
            else:
                return {
                    "is_valid": True,  # Grace period: allow opening with warning
                    "status": "trial_expired",
                    "days_left": 0,
                    "message": "Trial period ended. Please renew to continue unhindered access."
                }

        return {
            "is_valid": False,
            "status": "pending_setup",
            "message": "Organization requires setup fee payment or activation."
        }
