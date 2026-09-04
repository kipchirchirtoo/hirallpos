from typing import Any, List
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.rls import get_db, set_tenant_context
from app.models.organization import Organization
from app.models.branch import Branch
from app.schemas.organization import OrganizationOut, OrganizationUpdate

router = APIRouter()

@router.get("/{organization_id}", response_model=OrganizationOut)
def get_organization(
    organization_id: UUID,
    db: Session = Depends(get_db)
) -> Any:
    set_tenant_context(db, organization_id=str(organization_id))
    org = db.query(Organization).filter(Organization.id == organization_id).first()
    if not org:
        raise HTTPException(status_code=404, detail="Organization not found.")
    return org

@router.put("/{organization_id}", response_model=OrganizationOut)
def update_organization(
    organization_id: UUID,
    payload: OrganizationUpdate,
    db: Session = Depends(get_db)
) -> Any:
    set_tenant_context(db, organization_id=str(organization_id))
    org = db.query(Organization).filter(Organization.id == organization_id).first()
    if not org:
        raise HTTPException(status_code=404, detail="Organization not found.")
    
    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(org, field, value)
    
    db.commit()
    db.refresh(org)
    return org

@router.get("/", response_model=List[OrganizationOut])
def list_organizations_superadmin(
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db)
) -> Any:
    """
    Super-admin endpoint to list all platform organizations and their billing status.
    """
    orgs = db.query(Organization).offset(skip).limit(limit).all()
    return orgs
