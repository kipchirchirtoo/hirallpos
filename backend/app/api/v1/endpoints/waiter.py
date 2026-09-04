from typing import Any, List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.rls import get_db, set_tenant_context
from app.models.waiter import RestaurantTable, KitchenOrder
from app.models.branch import Branch
from pydantic import BaseModel

router = APIRouter()

class TableCreate(BaseModel):
    branch_id: UUID
    table_number: str
    capacity: int = 4

class TableStatusUpdate(BaseModel):
    status: str  # available | occupied | billing | reserved

class KitchenOrderCreate(BaseModel):
    branch_id: UUID
    table_id: Optional[UUID] = None
    items: list
    notes: Optional[str] = None

@router.get("/tables/branch/{branch_id}")
def list_tables(branch_id: UUID, db: Session = Depends(get_db)) -> Any:
    return db.query(RestaurantTable).filter(RestaurantTable.branch_id == branch_id).all()

@router.post("/tables")
def create_table(payload: TableCreate, db: Session = Depends(get_db)) -> Any:
    branch = db.query(Branch).filter(Branch.id == payload.branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found.")
    
    tbl = RestaurantTable(
        organization_id=branch.organization_id,
        branch_id=payload.branch_id,
        table_number=payload.table_number,
        capacity=payload.capacity,
        status="available"
    )
    db.add(tbl)
    db.commit()
    db.refresh(tbl)
    return tbl

@router.put("/tables/{table_id}/status")
def update_table_status(table_id: UUID, payload: TableStatusUpdate, db: Session = Depends(get_db)) -> Any:
    tbl = db.query(RestaurantTable).filter(RestaurantTable.id == table_id).first()
    if not tbl:
        raise HTTPException(status_code=404, detail="Table not found.")
    tbl.status = payload.status
    db.commit()
    return {"message": "Table status updated", "status": tbl.status}

@router.post("/kitchen-orders")
def send_kitchen_order(payload: KitchenOrderCreate, db: Session = Depends(get_db)) -> Any:
    branch = db.query(Branch).filter(Branch.id == payload.branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found.")
    
    order = KitchenOrder(
        organization_id=branch.organization_id,
        branch_id=payload.branch_id,
        table_id=payload.table_id,
        order_status="pending",
        items=payload.items,
        notes=payload.notes
    )
    db.add(order)
    db.commit()
    db.refresh(order)
    return order
