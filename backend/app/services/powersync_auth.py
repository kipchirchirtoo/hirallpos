import time
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict, Any
from jose import jwt
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
from app.core.config import settings

# In-memory ephemeral RSA keypair for development if none configured
_dev_private_key = None
_dev_public_key = None

def _get_or_create_dev_rsa_keys():
    global _dev_private_key, _dev_public_key
    if _dev_private_key is None:
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        _dev_private_key = key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption()
        ).decode("utf-8")
        _dev_public_key = key.public_key().public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo
        ).decode("utf-8")
    return _dev_private_key, _dev_public_key

class PowerSyncAuthService:
    @staticmethod
    def get_public_key() -> str:
        if settings.POWERSYNC_PUBLIC_KEY:
            return settings.POWERSYNC_PUBLIC_KEY
        _, public_key = _get_or_create_dev_rsa_keys()
        return public_key

    @classmethod
    def generate_token(
        cls,
        user_id: str,
        organization_id: str,
        role: str,
        branch_id: Optional[str] = None,
        expires_minutes: int = 60 * 24  # 24 hours
    ) -> str:
        """
        Generates an RS256 signed JWT for PowerSync client authentication.
        """
        now = datetime.now(timezone.utc)
        exp = now + timedelta(minutes=expires_minutes)
        
        payload = {
            "sub": str(user_id),
            "org_id": str(organization_id),
            "branch_id": str(branch_id) if branch_id else "",
            "role": role,
            "iat": int(now.timestamp()),
            "exp": int(exp.timestamp()),
            "iss": "hirall-pos-api",
            "aud": "powersync-service"
        }

        private_key = settings.POWERSYNC_PRIVATE_KEY
        if not private_key:
            private_key, _ = _get_or_create_dev_rsa_keys()

        return jwt.encode(payload, private_key, algorithm="RS256")
