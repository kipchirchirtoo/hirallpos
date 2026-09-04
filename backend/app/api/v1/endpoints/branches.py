from typing import Any, List
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.rls import get_db, set_tenant_context
from app.models.branch import Branch
from app.models.module import BranchModule, Module, BusinessTypeDefault
from app.models.organization import Organization
from app.schemas.branch import BranchCreate, BranchOut, BranchUpdate, BranchModuleInfo

router = APIRouter()

@router.get("/org/{organization_id}", response_model=List[BranchOut])
def list_org_branches(
    organization_id: UUID,
    db: Session = Depends(get_db)
) -> Any:
    set_tenant_context(db, organization_id=str(organization_id))
    branches = db.query(Branch).filter(Branch.organization_id == organization_id).all()
    
    result = []
    for branch in branches:
        # Fetch enabled modules
        modules_query = db.query(BranchModule, Module).join(
            Module, BranchModule.module_key == Module.key
        ).filter(BranchModule.branch_id == branch.id).all()
        
        mod_list = [
            BranchModuleInfo(
                module_key=bm.module_key,
                display_name=mod.display_name,
                is_enabled=bm.is_enabled,
                config=bm.config or {}
            )
            for bm, mod in modules_query
        ]
        
        branch_dict = {
            "id": branch.id,
            "organization_id": branch.organization_id,
            "name": branch.name,
            "location": branch.location,
            "till_number": branch.till_number,
            "is_active": branch.is_active,
            "created_at": branch.created_at,
            "modules": mod_list
        }
        result.append(branch_dict)
    
    return result

@router.post("/org/{organization_id}", response_model=BranchOut)
def create_branch(
    organization_id: UUID,
    payload: BranchCreate,
    db: Session = Depends(get_db)
) -> Any:
    set_tenant_context(db, organization_id=str(organization_id))
    org = db.query(Organization).filter(Organization.id == organization_id).first()
    if not org:
        raise HTTPException(status_code=404, detail="Organization not found.")

    branch = Branch(
        organization_id=organization_id,
        name=payload.name,
        location=payload.location,
        till_number=payload.till_number or f"TILL-{payload.name[:3].upper()}",
        is_active=True
    )
    db.add(branch)
    db.flush()

    # Seed default modules based on business_type
    defaults = db.query(BusinessTypeDefault).filter(
        BusinessTypeDefault.business_type == org.business_type
    ).all()
    module_keys = [d.module_key for d in defaults] if defaults else ["cashier", "storekeeping", "pos_outlets", "accounting"]

    for mod_key in module_keys:
        db.add(BranchModule(
            branch_id=branch.id,
            module_key=mod_key,
            is_enabled=True,
            config={}
        ))

    db.commit()
    db.refresh(branch)

    # Fetch modules info
    modules_query = db.query(BranchModule, Module).join(
        Module, BranchModule.module_key == Module.key
    ).filter(BranchModule.branch_id == branch.id).all()
    
    mod_list = [
        BranchModuleInfo(
            module_key=bm.module_key,
            display_name=mod.display_name,
            is_enabled=bm.is_enabled,
            config=bm.config or {}
        )
        for bm, mod in modules_query
    ]

    return {
        "id": branch.id,
        "organization_id": branch.organization_id,
        "name": branch.name,
        "location": branch.location,
        "till_number": branch.till_number,
        "is_active": branch.is_active,
        "created_at": branch.created_at,
        "modules": mod_list
    }

@router.put("/{branch_id}", response_model=BranchOut)
def update_branch(
    branch_id: UUID,
    payload: BranchUpdate,
    db: Session = Depends(get_db)
) -> Any:
    branch = db.query(Branch).filter(Branch.id == branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found.")
    
    set_tenant_context(db, organization_id=str(branch.organization_id), branch_id=str(branch.id))
    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(branch, field, value)

    db.commit()
    db.refresh(branch)

    modules_query = db.query(BranchModule, Module).join(
        Module, BranchModule.module_key == Module.key
    ).filter(BranchModule.branch_id == branch.id).all()
    
    mod_list = [
        BranchModuleInfo(
            module_key=bm.module_key,
            display_name=mod.display_name,
            is_enabled=bm.is_enabled,
            config=bm.config or {}
        )
        for bm, mod in modules_query
    ]

    return {
        "id": branch.id,
        "organization_id": branch.organization_id,
        "name": branch.name,
        "location": branch.location,
        "till_number": branch.till_number,
        "is_active": branch.is_active,
        "created_at": branch.created_at,
        "modules": mod_list
    }
