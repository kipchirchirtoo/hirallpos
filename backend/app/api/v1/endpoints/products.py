from typing import Any, List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session

from app.db.rls import get_db, set_tenant_context
from app.models.product import Product, Category
from app.models.inventory import Inventory
from app.schemas.product import (
    ProductCreate, ProductOut, ProductUpdate,
    CategoryCreate, CategoryOut
)

router = APIRouter()

# Category Endpoints
@router.get("/categories/{organization_id}", response_model=List[CategoryOut])
def list_categories(
    organization_id: UUID,
    db: Session = Depends(get_db)
) -> Any:
    set_tenant_context(db, organization_id=str(organization_id))
    return db.query(Category).filter(Category.organization_id == organization_id).all()

@router.post("/categories/{organization_id}", response_model=CategoryOut)
def create_category(
    organization_id: UUID,
    payload: CategoryCreate,
    db: Session = Depends(get_db)
) -> Any:
    set_tenant_context(db, organization_id=str(organization_id))
    category = Category(
        organization_id=organization_id,
        name=payload.name,
        color=payload.color
    )
    db.add(category)
    db.commit()
    db.refresh(category)
    return category

# Product Endpoints
@router.get("/org/{organization_id}", response_model=List[ProductOut])
def list_products(
    organization_id: UUID,
    branch_id: Optional[UUID] = None,
    category_id: Optional[UUID] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db)
) -> Any:
    set_tenant_context(db, organization_id=str(organization_id), branch_id=str(branch_id) if branch_id else None)
    query = db.query(Product).filter(Product.organization_id == organization_id, Product.is_active == True)
    
    if category_id:
        query = query.filter(Product.category_id == category_id)
    if search:
        search_fmt = f"%{search}%"
        query = query.filter(
            (Product.name.ilike(search_fmt)) | 
            (Product.barcode.ilike(search_fmt)) | 
            (Product.sku.ilike(search_fmt))
        )

    products = query.all()
    result = []
    for prod in products:
        stock = 0.0
        if branch_id:
            inv = db.query(Inventory).filter(
                Inventory.branch_id == branch_id,
                Inventory.product_id == prod.id
            ).first()
            if inv:
                stock = inv.current_stock
        
        result.append(ProductOut(
            id=prod.id,
            organization_id=prod.organization_id,
            category_id=prod.category_id,
            category_name=prod.category.name if prod.category else None,
            name=prod.name,
            sku=prod.sku,
            barcode=prod.barcode,
            cost_price=prod.cost_price,
            selling_price=prod.selling_price,
            tax_rate=prod.tax_rate,
            unit=prod.unit,
            is_active=prod.is_active,
            created_at=prod.created_at,
            current_stock=stock
        ))
    return result

@router.post("/org/{organization_id}", response_model=ProductOut)
def create_product(
    organization_id: UUID,
    payload: ProductCreate,
    db: Session = Depends(get_db)
) -> Any:
    set_tenant_context(db, organization_id=str(organization_id))
    prod = Product(
        organization_id=organization_id,
        category_id=payload.category_id,
        name=payload.name,
        sku=payload.sku,
        barcode=payload.barcode,
        cost_price=payload.cost_price,
        selling_price=payload.selling_price,
        tax_rate=payload.tax_rate,
        unit=payload.unit,
        is_active=payload.is_active
    )
    db.add(prod)
    db.flush()

    # Initial inventory if branch_id provided
    if payload.branch_id:
        inv = Inventory(
            organization_id=organization_id,
            branch_id=payload.branch_id,
            product_id=prod.id,
            current_stock=payload.initial_stock or 0.0,
            reorder_level=10.0
        )
        db.add(inv)

    db.commit()
    db.refresh(prod)
    return ProductOut(
        id=prod.id,
        organization_id=prod.organization_id,
        category_id=prod.category_id,
        name=prod.name,
        sku=prod.sku,
        barcode=prod.barcode,
        cost_price=prod.cost_price,
        selling_price=prod.selling_price,
        tax_rate=prod.tax_rate,
        unit=prod.unit,
        is_active=prod.is_active,
        created_at=prod.created_at,
        current_stock=payload.initial_stock or 0.0
    )
