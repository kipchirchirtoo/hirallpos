import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Float, DateTime, ForeignKey, Date
from sqlalchemy.dialects.postgresql import UUID
from app.db.session import Base

class Expense(Base):
    __tablename__ = "expenses"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False)
    branch_id = Column(UUID(as_uuid=True), ForeignKey("branches.id", ondelete="CASCADE"), nullable=False)
    category = Column(String(100), nullable=False)  # utilities | rent | petty_cash | supplies | salaries | maintenance
    description = Column(String(255), nullable=False)
    amount = Column(Float, nullable=False)
    paid_by_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    payment_method = Column(String(50), nullable=False, default="cash")
    expense_date = Column(Date, default=lambda: datetime.now(timezone.utc).date(), nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

class Shift(Base):
    __tablename__ = "shifts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False)
    branch_id = Column(UUID(as_uuid=True), ForeignKey("branches.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    start_time = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    end_time = Column(DateTime(timezone=True), nullable=True)
    initial_float = Column(Float, nullable=False, default=0.0)
    status = Column(String(50), nullable=False, default="open")  # open | closed

class TillReconciliation(Base):
    __tablename__ = "till_reconciliations"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False)
    branch_id = Column(UUID(as_uuid=True), ForeignKey("branches.id", ondelete="CASCADE"), nullable=False)
    shift_id = Column(UUID(as_uuid=True), ForeignKey("shifts.id", ondelete="CASCADE"), nullable=True)
    cashier_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    opening_float = Column(Float, nullable=False, default=0.0)
    closing_cash = Column(Float, nullable=False, default=0.0)
    closing_mpesa = Column(Float, nullable=False, default=0.0)
    closing_card = Column(Float, nullable=False, default=0.0)
    total_expected = Column(Float, nullable=False, default=0.0)
    total_actual = Column(Float, nullable=False, default=0.0)
    variance = Column(Float, nullable=False, default=0.0)  # positive = overage, negative = shortage
    notes = Column(String(255), nullable=True)
    status = Column(String(50), nullable=False, default="verified")  # verified | flagged
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
