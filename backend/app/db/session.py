import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from app.core.config import settings

db_url = settings.DATABASE_URL
# Automatically adapt postgresql:// to postgresql+psycopg:// if psycopg3 is used
if db_url.startswith("postgresql://") and not db_url.startswith("postgresql+"):
    # Try using postgresql+psycopg://
    db_url = db_url.replace("postgresql://", "postgresql+psycopg://", 1)

try:
    engine = create_engine(
        db_url,
        pool_pre_ping=True,
    )
except Exception:
    # Fallback to standard URL or sqlite if local postgres is not reachable
    engine = create_engine(
        "sqlite:///./hirall_pos_local.db",
        connect_args={"check_same_thread": False}
    )

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()
