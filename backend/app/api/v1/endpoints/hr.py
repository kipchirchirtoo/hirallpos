from typing import Any, List, Optional
from uuid import UUID
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr

from app.db.rls import get_db, set_tenant_context
from app.models.user import User
from app.models.hr import Attendance
from app.models.branch import Branch
from app.core.security import get_password_hash
from app.schemas.auth import UserOut, UserCreate

router = APIRouter()

class AttendanceClockIn(BaseModel):
    branch_id: UUID
    user_id: UUID

class AttendanceClockOut(BaseModel):
    attendance_id: UUID

@router.get("/staff/org/{organization_id}", response_model=List[UserOut])
def list_staff(organization_id: UUID, db: Session = Depends(get_db)) -> Any:
    set_tenant_context(db, organization_id=str(organization_id))
    return db.query(User).filter(User.organization_id == organization_id).all()

@router.post("/staff/org/{organization_id}", response_model=UserOut)
def create_staff(
    organization_id: UUID,
    payload: UserCreate,
    db: Session = Depends(get_db)
) -> Any:
    set_tenant_context(db, organization_id=str(organization_id))
    existing = db.query(User).filter(User.email == payload.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="User with this email already exists.")

    user = User(
        organization_id=organization_id,
        branch_id=payload.branch_id,
        email=payload.email,
        full_name=payload.full_name,
        password_hash=get_password_hash(payload.password),
        pin_code=payload.pin_code or "1234",
        role=payload.role,
        is_active=True
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user

@router.post("/attendance/clock-in")
def clock_in(payload: AttendanceClockIn, db: Session = Depends(get_db)) -> Any:
    user = db.query(User).filter(User.id == payload.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")

    att = Attendance(
        organization_id=user.organization_id,
        branch_id=payload.branch_id,
        user_id=payload.user_id,
        clock_in=datetime.now(timezone.utc),
        status="present"
    )
    db.add(att)
    db.commit()
    db.refresh(att)
    return {"message": "Clock-in recorded", "attendance_id": str(att.id), "clock_in": att.clock_in}

@router.post("/attendance/clock-out")
def clock_out(payload: AttendanceClockOut, db: Session = Depends(get_db)) -> Any:
    att = db.query(Attendance).filter(Attendance.id == payload.attendance_id).first()
    if not att:
        raise HTTPException(status_code=404, detail="Attendance record not found.")

    now = datetime.now(timezone.utc)
    att.clock_out = now
    total_seconds = (now - att.clock_in).total_seconds()
    att.total_hours = round(total_seconds / 3600.0, 2)

    db.commit()
    return {"message": "Clock-out recorded", "total_hours": att.total_hours}
