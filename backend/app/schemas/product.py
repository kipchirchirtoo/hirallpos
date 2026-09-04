from typing import Optional, List
from pydantic import BaseModel
from uuid import UUID
from datetime import datetime

class CategoryBase(BaseModel):
    name: str
    color: str = "#2563EB"

class CategoryCreate(CategoryBase):
    pass

class CategoryOut(CategoryBase):
    id: UUID
    organization_id: UUID
    created_at: datetime

    class Config:
        from_attributes = True

class ProductBase(BaseModel):
    name: str
    category_id: Optional[UUID] = None
    sku: Optional[str] = None
    barcode: Optional[str] = None
    cost_price: float = 0.0
    selling_price: float = 0.0
    tax_rate: float = 16.0
    unit: str = "pcs"
    is_active: bool = True

class ProductCreate(ProductBase):
    initial_stock: Optional[float] = 0.0
    branch_id: Optional[UUID] = None

class ProductUpdate(BaseModel):
    name: Optional[str] = None
    category_id: Optional[UUID] = None
    sku: Optional[str] = None
    barcode: Optional[str] = None
    cost_price: Optional[float] = None
    selling_price: Optional[float] = None
    tax_rate: Optional[float] = None
    unit: Optional[str] = None
    is_active: Optional[bool] = None

class ProductOut(ProductBase):
    id: UUID
    organization_id: UUID
    created_at: datetime
    current_stock: Optional[float] = 0.0
    category_name: Optional[str] = None

    class Config:
        from_attributes = True
