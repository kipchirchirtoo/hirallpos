from typing import Any, List
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.rls import get_db, set_tenant_context
from app.models.inventory import Inventory, StockTransfer
from app.models.product import Product
from app.models.branch import Branch
from app.schemas.inventory import (
    InventoryOut, InventoryUpdate, StockReceiveRequest,
    StockTransferCreate, StockTransferOut
)

router = APIRouter()

@router.get("/branch/{branch_id}", response_model=List[InventoryOut])
def list_branch_inventory(
    branch_id: UUID,
    db: Session = Depends(get_db)
) -> Any:
    branch = db.query(Branch).filter(Branch.id == branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found.")

    set_tenant_context(db, organization_id=str(branch.organization_id), branch_id=str(branch.id))

    records = db.query(Inventory, Product).join(
        Product, Inventory.product_id == Product.id
    ).filter(Inventory.branch_id == branch_id).all()

    result = []
    for inv, prod in records:
        result.append(InventoryOut(
            id=inv.id,
            organization_id=inv.organization_id,
            branch_id=inv.branch_id,
            product_id=inv.product_id,
            product_name=prod.name,
            sku=prod.sku,
            barcode=prod.barcode,
            current_stock=inv.current_stock,
            reorder_level=inv.reorder_level,
            cost_price=prod.cost_price,
            selling_price=prod.selling_price,
            updated_at=inv.updated_at
        ))
    return result

@router.post("/receive")
def receive_stock(
    payload: StockReceiveRequest,
    db: Session = Depends(get_db)
) -> Any:
    branch = db.query(Branch).filter(Branch.id == payload.branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found.")

    set_tenant_context(db, organization_id=str(branch.organization_id), branch_id=str(branch.id))

    inv = db.query(Inventory).filter(
        Inventory.branch_id == payload.branch_id,
        Inventory.product_id == payload.product_id
    ).first()

    if not inv:
        inv = Inventory(
            organization_id=branch.organization_id,
            branch_id=payload.branch_id,
            product_id=payload.product_id,
            current_stock=payload.quantity,
            reorder_level=10.0
        )
        db.add(inv)
    else:
        inv.current_stock += payload.quantity

    if payload.cost_price is not None:
        prod = db.query(Product).filter(Product.id == payload.product_id).first()
        if prod:
            prod.cost_price = payload.cost_price

    db.commit()
    return {"message": "Stock received successfully", "new_stock": inv.current_stock}

@router.post("/transfers", response_model=StockTransferOut)
def create_stock_transfer(
    payload: StockTransferCreate,
    db: Session = Depends(get_db)
) -> Any:
    src_branch = db.query(Branch).filter(Branch.id == payload.source_branch_id).first()
    if not src_branch:
        raise HTTPException(status_code=404, detail="Source branch not found.")

    set_tenant_context(db, organization_id=str(src_branch.organization_id))

    # Deduct from source branch
    src_inv = db.query(Inventory).filter(
        Inventory.branch_id == payload.source_branch_id,
        Inventory.product_id == payload.product_id
    ).first()

    if not src_inv or src_inv.current_stock < payload.quantity:
        raise HTTPException(status_code=400, detail="Insufficient stock in source branch.")

    src_inv.current_stock -= payload.quantity

    # Add to destination branch
    dest_inv = db.query(Inventory).filter(
        Inventory.branch_id == payload.destination_branch_id,
        Inventory.product_id == payload.product_id
    ).first()

    if not dest_inv:
        dest_inv = Inventory(
            organization_id=src_branch.organization_id,
            branch_id=payload.destination_branch_id,
            product_id=payload.product_id,
            current_stock=payload.quantity,
            reorder_level=10.0
        )
        db.add(dest_inv)
    else:
        dest_inv.current_stock += payload.quantity

    transfer = StockTransfer(
        organization_id=src_branch.organization_id,
        source_branch_id=payload.source_branch_id,
        destination_branch_id=payload.destination_branch_id,
        product_id=payload.product_id,
        quantity=payload.quantity,
        status="received",
        notes=payload.notes
    )
    db.add(transfer)
    db.commit()
    db.refresh(transfer)

    prod = db.query(Product).filter(Product.id == payload.product_id).first()

    return StockTransferOut(
        id=transfer.id,
        organization_id=transfer.organization_id,
        source_branch_id=transfer.source_branch_id,
        destination_branch_id=transfer.destination_branch_id,
        product_id=transfer.product_id,
        product_name=prod.name if prod else None,
        quantity=transfer.quantity,
        status=transfer.status,
        notes=transfer.notes,
        created_at=transfer.created_at
    )
