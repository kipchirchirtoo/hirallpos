import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Boolean, DateTime, Float
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.db.session import Base

class Organization(Base):
    __tablename__ = "organizations"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    business_type = Column(String(50), nullable=False)  # supermarket | retail | restaurant | bar_club | laundry | spa | car_wash
    subdomain = Column(String(100), unique=True, nullable=True)
    owner_name = Column(String(255), nullable=False)
    phone_number = Column(String(50), nullable=False)
    plan = Column(String(50), nullable=False, default="trial")  # trial | starter | pro | enterprise
    billing_status = Column(String(50), nullable=False, default="pending_setup_fee")  # pending_setup_fee | active | past_due | cancelled
    setup_fee_paid = Column(Boolean, nullable=False, default=False)
    license_key = Column(String(100), unique=True, nullable=True)
    trial_ends_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    branches = relationship("Branch", back_populates="organization", cascade="all, delete-orphan")
    users = relationship("User", back_populates="organization", cascade="all, delete-orphan")
