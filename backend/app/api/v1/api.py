from fastapi import APIRouter
from app.api.v1.endpoints import (
    auth,
    organizations,
    branches,
    modules,
    billing,
    products,
    sales,
    inventory,
    accounting,
    waiter,
    hr
)

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["Auth & Licensing"])
api_router.include_router(organizations.router, prefix="/organizations", tags=["Organizations"])
api_router.include_router(branches.router, prefix="/branches", tags=["Branches"])
api_router.include_router(modules.router, prefix="/modules", tags=["Modules"])
api_router.include_router(billing.router, prefix="/billing", tags=["Billing & M-Pesa"])
api_router.include_router(products.router, prefix="/products", tags=["Products & Catalog"])
api_router.include_router(sales.router, prefix="/sales", tags=["Sales & POS"])
api_router.include_router(inventory.router, prefix="/inventory", tags=["Inventory & Storekeeping"])
api_router.include_router(accounting.router, prefix="/accounting", tags=["Accounting & Reconciliations"])
api_router.include_router(waiter.router, prefix="/waiter", tags=["Waiter & Restaurant"])
api_router.include_router(hr.router, prefix="/hr", tags=["HR & Staff"])
