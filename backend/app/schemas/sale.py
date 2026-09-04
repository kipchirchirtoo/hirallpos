from typing import Optional, List
from pydantic import BaseModel
from uuid import UUID
from datetime import datetime

class SaleItemCreate(BaseModel):
    product_id: Optional[UUID] = None
    product_name: str
    quantity: float = 1.0
    unit_price: float
    tax_amount: float = 0.0
    total_price: float

class SaleItemOut(SaleItemCreate):
    id: UUID
    sale_id: UUID

    class Config:
        from_attributes = True

class SaleCreate(BaseModel):
    branch_id: UUID
    receipt_number: str
    customer_name: Optional[str] = None
    customer_phone: Optional[str] = None
    subtotal: float
    discount: float = 0.0
    tax_amount: float = 0.0
    total_amount: float
    payment_method: str = "cash"  # cash | mpesa | card | split
    mpesa_receipt_number: Optional[str] = None
    items: List[SaleItemCreate]

class SaleOut(BaseModel):
    id: UUID
    organization_id: UUID
    branch_id: UUID
    receipt_number: str
    cashier_id: Optional[UUID] = None
    customer_name: Optional[str] = None
    customer_phone: Optional[str] = None
    subtotal: float
    discount: float
    tax_amount: float
    total_amount: float
    payment_method: str
    mpesa_receipt_number: Optional[str] = None
    payment_status: str
    sync_status: str
    created_at: datetime
    items: List[SaleItemOut] = []

    class Config:
        from_attributes = True
