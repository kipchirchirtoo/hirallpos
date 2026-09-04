import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Integer, DateTime, ForeignKey, JSON
from sqlalchemy.dialects.postgresql import UUID
from app.db.session import Base

class RestaurantTable(Base):
    __tablename__ = "restaurant_tables"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False)
    branch_id = Column(UUID(as_uuid=True), ForeignKey("branches.id", ondelete="CASCADE"), nullable=False)
    table_number = Column(String(50), nullable=False)
    capacity = Column(Integer, nullable=False, default=4)
    status = Column(String(50), nullable=False, default="available")  # available | occupied | billing | reserved
    current_order_id = Column(UUID(as_uuid=True), nullable=True)

class KitchenOrder(Base):
    __tablename__ = "kitchen_orders"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False)
    branch_id = Column(UUID(as_uuid=True), ForeignKey("branches.id", ondelete="CASCADE"), nullable=False)
    table_id = Column(UUID(as_uuid=True), ForeignKey("restaurant_tables.id", ondelete="SET NULL"), nullable=True)
    waiter_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    order_status = Column(String(50), nullable=False, default="pending")  # pending | in_prep | ready | served | cancelled
    items = Column(JSON, nullable=False, default=list)  # list of {product_id, name, qty, notes}
    notes = Column(String(255), nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
