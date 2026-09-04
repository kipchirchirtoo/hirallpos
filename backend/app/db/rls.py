from typing import Optional, Generator
from sqlalchemy import text
from sqlalchemy.orm import Session
from app.db.session import SessionLocal

def set_tenant_context(db: Session, organization_id: Optional[str] = None, branch_id: Optional[str] = None):
    """
    Sets the current tenant context for PostgreSQL Row-Level Security (RLS).
    Uses set_config(setting_name, new_value, is_local=true) for transaction-scoped RLS.
    """
    try:
        if organization_id:
            db.execute(text("SELECT set_config('app.current_org_id', :org_id, true)"), {"org_id": str(organization_id)})
        if branch_id:
            db.execute(text("SELECT set_config('app.current_branch_id', :branch_id, true)"), {"branch_id": str(branch_id)})
    except Exception as e:
        pass

def get_db() -> Generator[Session, None, None]:
    """
    FastAPI dependency yielding a database session.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
