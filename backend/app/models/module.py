from sqlalchemy import Column, String, Boolean, ForeignKey, JSON
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from app.db.session import Base

class Module(Base):
    __tablename__ = "modules"

    key = Column(String(50), primary_key=True)  # 'cashier' | 'waiter' | 'storekeeping' | 'accounting' | 'hr_management' | 'pos_outlets'
    display_name = Column(String(100), nullable=False)
    description = Column(String(255), nullable=True)

class BranchModule(Base):
    __tablename__ = "branch_modules"

    branch_id = Column(UUID(as_uuid=True), ForeignKey("branches.id", ondelete="CASCADE"), primary_key=True)
    module_key = Column(String(50), ForeignKey("modules.key", ondelete="CASCADE"), primary_key=True)
    is_enabled = Column(Boolean, nullable=False, default=True)
    config = Column(JSON, nullable=False, default=dict)

    # Relationships
    branch = relationship("Branch", back_populates="modules")
    module = relationship("Module")

class BusinessTypeDefault(Base):
    __tablename__ = "business_type_defaults"

    business_type = Column(String(50), primary_key=True)
    module_key = Column(String(50), ForeignKey("modules.key", ondelete="CASCADE"), primary_key=True)
