import os
from typing import List, Optional
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    PROJECT_NAME: str = "Hirall POS API"
    VERSION: str = "2.0.0"
    API_V1_STR: str = "/api/v1"
    
    # Environment
    ENVIRONMENT: str = "development"
    DEBUG: bool = True
    
    # Database
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL", 
        "postgresql://postgres:postgres@localhost:5432/hirall_pos"
    )

    # AWS RDS Direct Parameters (Optional / Informational)
    RDS_HOSTNAME: Optional[str] = None
    RDS_PORT: Optional[int] = 5432
    RDS_DB_NAME: Optional[str] = "hirall_pos"
    RDS_USERNAME: Optional[str] = "postgres"
    RDS_PASSWORD: Optional[str] = None
    AWS_REGION: Optional[str] = "eu-west-1"
    
    # JWT Security
    SECRET_KEY: str = os.getenv("SECRET_KEY", "super-secret-hirall-pos-key-change-in-production-2026-xyz")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days
    
    # PowerSync RS256 Key for Token Minting
    POWERSYNC_PRIVATE_KEY: Optional[str] = os.getenv("POWERSYNC_PRIVATE_KEY", None)
    POWERSYNC_PUBLIC_KEY: Optional[str] = os.getenv("POWERSYNC_PUBLIC_KEY", None)
    POWERSYNC_URL: Optional[str] = os.getenv("POWERSYNC_URL", "https://sync.powersync.com")
    
    # M-Pesa Integration (Daraja / PayHero)
    MPESA_ENVIRONMENT: str = os.getenv("MPESA_ENVIRONMENT", "sandbox")  # sandbox | production
    MPESA_CONSUMER_KEY: Optional[str] = os.getenv("MPESA_CONSUMER_KEY", "mock_consumer_key")
    MPESA_CONSUMER_SECRET: Optional[str] = os.getenv("MPESA_CONSUMER_SECRET", "mock_consumer_secret")
    MPESA_SHORTCODE: Optional[str] = os.getenv("MPESA_SHORTCODE", "174379")
    MPESA_PASSKEY: Optional[str] = os.getenv("MPESA_PASSKEY", "bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919")
    MPESA_CALLBACK_URL: str = os.getenv(
        "MPESA_CALLBACK_URL", 
        "https://api.hirallpos.com/api/v1/billing/mpesa-callback"
    )
    
    # Setup Fee Defaults (KES)
    DEFAULT_SETUP_FEE_KES: float = 5000.0
    
    # CORS Origins
    BACKEND_CORS_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:3001",
        "http://127.0.0.1:3000",
        "http://localhost:8000",
        "http://192.168.100.30:3000",
        "http://192.168.100.30:3001",
        "http://192.168.100.30:8000",
        "http://192.168.100.30",
        "https://admin.hirallpos.com",
    ]
    
    model_config = SettingsConfigDict(case_sensitive=True, env_file=".env", extra="ignore")

settings = Settings()
