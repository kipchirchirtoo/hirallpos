from typing import Any, List
from uuid import UUID
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.rls import get_db, set_tenant_context
from app.models.sale import Sale, SaleItem
from app.models.inventory import Inventory
from app.models.branch import Branch
from app.schemas.sale import SaleCreate, SaleOut

router = APIRouter()

@router.post("/branch/{branch_id}", response_model=SaleOut)
def record_sale(
    branch_id: UUID,
    payload: SaleCreate,
    db: Session = Depends(get_db)
) -> Any:
    branch = db.query(Branch).filter(Branch.id == branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found.")

    set_tenant_context(db, organization_id=str(branch.organization_id), branch_id=str(branch.id))

    sale = Sale(
        organization_id=branch.organization_id,
        branch_id=branch_id,
        receipt_number=payload.receipt_number,
        customer_name=payload.customer_name,
        customer_phone=payload.customer_phone,
        subtotal=payload.subtotal,
        discount=payload.discount,
        tax_amount=payload.tax_amount,
        total_amount=payload.total_amount,
        payment_method=payload.payment_method,
        mpesa_receipt_number=payload.mpesa_receipt_number,
        payment_status="completed",
        sync_status="synced"
    )
    db.add(sale)
    db.flush()

    for item in payload.items:
        sale_item = SaleItem(
            sale_id=sale.id,
            product_id=item.product_id,
            product_name=item.product_name,
            quantity=item.quantity,
            unit_price=item.unit_price,
            tax_amount=item.tax_amount,
            total_price=item.total_price
        )
        db.add(sale_item)

        # Decrement inventory
        if item.product_id:
            inv = db.query(Inventory).filter(
                Inventory.branch_id == branch_id,
                Inventory.product_id == item.product_id
            ).first()
            if inv:
                inv.current_stock -= item.quantity

    db.commit()
    db.refresh(sale)
    return sale

@router.get("/branch/{branch_id}", response_model=List[SaleOut])
def list_branch_sales(
    branch_id: UUID,
    limit: int = 100,
    db: Session = Depends(get_db)
) -> Any:
    branch = db.query(Branch).filter(Branch.id == branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found.")

    set_tenant_context(db, organization_id=str(branch.organization_id), branch_id=str(branch.id))
    sales = db.query(Sale).filter(
        Sale.branch_id == branch_id
    ).order_by(Sale.created_at.desc()).limit(limit).all()
    
    return sales
