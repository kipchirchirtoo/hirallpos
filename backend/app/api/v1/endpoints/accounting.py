from typing import Any, List
from uuid import UUID
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.db.rls import get_db, set_tenant_context
from app.models.accounting import Expense, Shift, TillReconciliation
from app.models.sale import Sale
from app.models.branch import Branch
from app.schemas.accounting import (
    ExpenseCreate, ExpenseOut,
    TillReconciliationCreate, TillReconciliationOut,
    ShiftCreate, ShiftOut
)

router = APIRouter()

# Expenses
@router.get("/expenses/branch/{branch_id}", response_model=List[ExpenseOut])
def list_branch_expenses(
    branch_id: UUID,
    db: Session = Depends(get_db)
) -> Any:
    branch = db.query(Branch).filter(Branch.id == branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found.")

    set_tenant_context(db, organization_id=str(branch.organization_id), branch_id=str(branch.id))
    return db.query(Expense).filter(Expense.branch_id == branch_id).order_by(Expense.created_at.desc()).all()

@router.post("/expenses", response_model=ExpenseOut)
def record_expense(
    payload: ExpenseCreate,
    db: Session = Depends(get_db)
) -> Any:
    branch = db.query(Branch).filter(Branch.id == payload.branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found.")

    set_tenant_context(db, organization_id=str(branch.organization_id), branch_id=str(branch.id))

    expense = Expense(
        organization_id=branch.organization_id,
        branch_id=payload.branch_id,
        category=payload.category,
        description=payload.description,
        amount=payload.amount,
        payment_method=payload.payment_method,
        expense_date=payload.expense_date or datetime.now(timezone.utc).date()
    )
    db.add(expense)
    db.commit()
    db.refresh(expense)
    return expense

# Till Reconciliation
@router.post("/reconciliations", response_model=TillReconciliationOut)
def record_till_reconciliation(
    payload: TillReconciliationCreate,
    db: Session = Depends(get_db)
) -> Any:
    branch = db.query(Branch).filter(Branch.id == payload.branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found.")

    set_tenant_context(db, organization_id=str(branch.organization_id), branch_id=str(branch.id))

    total_actual = payload.closing_cash + payload.closing_mpesa + payload.closing_card
    variance = total_actual - payload.total_expected

    rec = TillReconciliation(
        organization_id=branch.organization_id,
        branch_id=payload.branch_id,
        shift_id=payload.shift_id,
        opening_float=payload.opening_float,
        closing_cash=payload.closing_cash,
        closing_mpesa=payload.closing_mpesa,
        closing_card=payload.closing_card,
        total_expected=payload.total_expected,
        total_actual=total_actual,
        variance=variance,
        notes=payload.notes,
        status="flagged" if abs(variance) > 50 else "verified"
    )
    db.add(rec)
    db.commit()
    db.refresh(rec)
    return rec

# Financial Summary / P&L
@router.get("/summary/branch/{branch_id}")
def get_branch_financial_summary(
    branch_id: UUID,
    db: Session = Depends(get_db)
) -> Any:
    branch = db.query(Branch).filter(Branch.id == branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found.")

    set_tenant_context(db, organization_id=str(branch.organization_id), branch_id=str(branch.id))

    total_sales = db.query(func.sum(Sale.total_amount)).filter(Sale.branch_id == branch_id).scalar() or 0.0
    total_tax = db.query(func.sum(Sale.tax_amount)).filter(Sale.branch_id == branch_id).scalar() or 0.0
    total_expenses = db.query(func.sum(Expense.amount)).filter(Expense.branch_id == branch_id).scalar() or 0.0
    net_profit = total_sales - total_tax - total_expenses

    return {
        "branch_id": str(branch_id),
        "branch_name": branch.name,
        "total_revenue": total_sales,
        "total_vat_collected": total_tax,
        "total_expenses": total_expenses,
        "net_profit": net_profit
    }
