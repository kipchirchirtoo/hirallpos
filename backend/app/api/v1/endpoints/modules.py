from typing import Any, List, Dict
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.rls import get_db, set_tenant_context
from app.models.module import Module, BranchModule, BusinessTypeDefault
from app.schemas.module import ModuleOut, BranchModuleUpdate, BusinessTypeInfo

router = APIRouter()

# Default Business Type Catalog
BUSINESS_TYPE_DEFINITIONS = [
    {
        "business_type": "supermarket",
        "label": "Supermarket & Hypermarket",
        "description": "High-volume retail with barcode scanning, cashier lanes, inventory receiving, and inter-branch transfers.",
        "default_modules": ["cashier", "storekeeping", "accounting", "hr_management", "pos_outlets"]
    },
    {
        "business_type": "retail",
        "label": "Retail Store & Boutique",
        "description": "General merchandise, electronics, clothing, and hardware with stock management and daily sales.",
        "default_modules": ["cashier", "storekeeping", "accounting", "pos_outlets"]
    },
    {
        "business_type": "restaurant",
        "label": "Restaurant & Fast Food",
        "description": "Table management, waiter ordering, kitchen order tickets (KOT), split bills, and food cost accounting.",
        "default_modules": ["cashier", "waiter", "storekeeping", "accounting", "hr_management", "pos_outlets"]
    },
    {
        "business_type": "bar_club",
        "label": "Bar, Lounge & Club",
        "description": "High-speed beverage cashiering, bottle inventory tracking, tab management, and shift reconciliations.",
        "default_modules": ["cashier", "waiter", "storekeeping", "accounting", "pos_outlets"]
    },
    {
        "business_type": "laundry",
        "label": "Laundromat & Dry Cleaning",
        "description": "Customer drop-off tracking, order garment tags, service cashiering, and SMS collection reminders.",
        "default_modules": ["cashier", "accounting", "hr_management", "pos_outlets"]
    },
    {
        "business_type": "spa",
        "label": "Spa, Salon & Wellness",
        "description": "Service menu, specialist commission tracking, appointment booking, and customer loyalty cashiering.",
        "default_modules": ["cashier", "accounting", "hr_management", "pos_outlets"]
    },
    {
        "business_type": "car_wash",
        "label": "Car Wash & Detailing",
        "description": "Vehicle service tracking, quick ticket generation, attendant commission payout, and daily cash float.",
        "default_modules": ["cashier", "accounting", "hr_management", "pos_outlets"]
    },
]

@router.get("/catalog", response_model=List[ModuleOut])
def get_module_catalog(db: Session = Depends(get_db)) -> Any:
    """
    Returns the fixed list of modules shipped on the platform.
    """
    modules = db.query(Module).all()
    return modules

@router.get("/business-types", response_model=List[BusinessTypeInfo])
def get_business_types() -> Any:
    """
    Returns all supported business types with their recommended module bundles.
    """
    return BUSINESS_TYPE_DEFINITIONS

@router.put("/branch/{branch_id}/{module_key}")
def toggle_branch_module(
    branch_id: UUID,
    module_key: str,
    payload: BranchModuleUpdate,
    db: Session = Depends(get_db)
) -> Any:
    """
    Toggle a module on or off for a specific branch and update module-specific config.
    """
    bm = db.query(BranchModule).filter(
        BranchModule.branch_id == branch_id,
        BranchModule.module_key == module_key
    ).first()

    if not bm:
        # Create module binding if not present
        bm = BranchModule(
            branch_id=branch_id,
            module_key=module_key,
            is_enabled=payload.is_enabled,
            config=payload.config or {}
        )
        db.add(bm)
    else:
        bm.is_enabled = payload.is_enabled
        if payload.config is not None:
            bm.config = payload.config

    db.commit()
    db.refresh(bm)
    return {
        "branch_id": str(branch_id),
        "module_key": module_key,
        "is_enabled": bm.is_enabled,
        "config": bm.config
    }
