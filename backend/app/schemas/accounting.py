from typing import Optional
from pydantic import BaseModel
from uuid import UUID
from datetime import datetime, date

class ExpenseCreate(BaseModel):
    branch_id: UUID
    category: str
    description: str
    amount: float
    payment_method: str = "cash"
    expense_date: Optional[date] = None

class ExpenseOut(ExpenseCreate):
    id: UUID
    organization_id: UUID
    paid_by_user_id: Optional[UUID] = None
    created_at: datetime

    class Config:
        from_attributes = True

class TillReconciliationCreate(BaseModel):
    branch_id: UUID
    shift_id: Optional[UUID] = None
    opening_float: float
    closing_cash: float
    closing_mpesa: float
    closing_card: float
    total_expected: float
    notes: Optional[str] = None

class TillReconciliationOut(TillReconciliationCreate):
    id: UUID
    organization_id: UUID
    cashier_id: Optional[UUID] = None
    total_actual: float
    variance: float
    status: str
    created_at: datetime

    class Config:
        from_attributes = True

class ShiftCreate(BaseModel):
    branch_id: UUID
    initial_float: float

class ShiftOut(BaseModel):
    id: UUID
    organization_id: UUID
    branch_id: UUID
    user_id: UUID
    start_time: datetime
    end_time: Optional[datetime] = None
    initial_float: float
    status: str

    class Config:
        from_attributes = True
