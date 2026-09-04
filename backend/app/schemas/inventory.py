from typing import Optional
from pydantic import BaseModel
from uuid import UUID
from datetime import datetime

class InventoryUpdate(BaseModel):
    branch_id: UUID
    product_id: UUID
    current_stock: float
    reorder_level: Optional[float] = None

class InventoryOut(BaseModel):
    id: UUID
    organization_id: UUID
    branch_id: UUID
    product_id: UUID
    product_name: str
    sku: Optional[str] = None
    barcode: Optional[str] = None
    current_stock: float
    reorder_level: float
    cost_price: float
    selling_price: float
    updated_at: datetime

    class Config:
        from_attributes = True

class StockReceiveRequest(BaseModel):
    branch_id: UUID
    product_id: UUID
    quantity: float
    cost_price: Optional[float] = None
    supplier_name: Optional[str] = None
    invoice_number: Optional[str] = None

class StockTransferCreate(BaseModel):
    source_branch_id: UUID
    destination_branch_id: UUID
    product_id: UUID
    quantity: float
    notes: Optional[str] = None

class StockTransferOut(StockTransferCreate):
    id: UUID
    organization_id: UUID
    status: str
    product_name: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True
