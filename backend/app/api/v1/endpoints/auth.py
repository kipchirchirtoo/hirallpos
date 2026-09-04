from datetime import datetime, timezone, timedelta
from typing import Any
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.db.rls import get_db, set_tenant_context
from app.core.security import create_access_token, verify_password, get_password_hash
from app.core.config import settings
from app.models.organization import Organization
from app.models.branch import Branch
from app.models.module import Module, BranchModule, BusinessTypeDefault
from app.models.user import User
from app.schemas.auth import (
    Token,
    LoginRequest,
    PinLoginRequest,
    RegisterOrgRequest,
    LicenseVerificationRequest,
    LicenseVerificationResponse,
    UserOut
)
from app.services.licensing import LicensingService
from app.services.powersync_auth import PowerSyncAuthService

router = APIRouter()

@router.post("/register-org", response_model=Token)
def register_organization(
    payload: RegisterOrgRequest,
    db: Session = Depends(get_db)
) -> Any:
    """
    Onboard a new organization from the Admin Web Portal:
    1. Create Organization with selected business type.
    2. Create Primary Branch.
    3. Seed default branch modules from business_type_defaults.
    4. Create Owner user account.
    5. Issue License Activation Key (14-day trial).
    """
    # Check if email is already taken
    existing_user = db.query(User).filter(User.email == payload.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A user with this email already exists."
        )

    # 1. Create Organization
    license_key = LicensingService.generate_license_key()
    trial_expiry = LicensingService.calculate_trial_expiry(14)
    
    org = Organization(
        name=payload.name,
        business_type=payload.business_type,
        subdomain=payload.subdomain,
        owner_name=payload.owner_name,
        phone_number=payload.phone_number,
        plan="trial",
        billing_status="pending_setup_fee",
        setup_fee_paid=False,
        license_key=license_key,
        trial_ends_at=trial_expiry
    )
    db.add(org)
    db.flush()

    # 2. Create Primary Branch
    primary_branch = Branch(
        organization_id=org.id,
        name=payload.primary_branch_name,
        location="Headquarters",
        till_number="TILL-01",
        is_active=True
    )
    db.add(primary_branch)
    db.flush()

    # 3. Seed default branch modules based on business_type
    defaults = db.query(BusinessTypeDefault).filter(
        BusinessTypeDefault.business_type == payload.business_type
    ).all()
    
    # Fallback to cashier + storekeeping + outlets if no specific defaults found
    module_keys = [d.module_key for d in defaults] if defaults else ["cashier", "storekeeping", "pos_outlets", "accounting"]
    
    for mod_key in module_keys:
        db.add(BranchModule(
            branch_id=primary_branch.id,
            module_key=mod_key,
            is_enabled=True,
            config={}
        ))

    # 4. Create Owner user
    owner = User(
        organization_id=org.id,
        branch_id=primary_branch.id,
        email=payload.email,
        full_name=payload.owner_name,
        password_hash=get_password_hash(payload.password),
        pin_code="1234",
        role="owner",
        is_active=True
    )
    db.add(owner)
    db.commit()
    db.refresh(owner)

    token = create_access_token(
        subject=owner.id,
        organization_id=str(org.id),
        branch_id=str(primary_branch.id),
        role="owner"
    )

    return {
        "access_token": token,
        "token_type": "bearer",
        "user_id": str(owner.id),
        "organization_id": str(org.id),
        "branch_id": str(primary_branch.id),
        "role": "owner",
        "full_name": owner.full_name,
        "email": owner.email
    }

@router.post("/login", response_model=Token)
def login(
    payload: LoginRequest,
    db: Session = Depends(get_db)
) -> Any:
    user = db.query(User).filter(User.email == payload.email).first()
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password."
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive."
        )

    token = create_access_token(
        subject=user.id,
        organization_id=str(user.organization_id),
        branch_id=str(user.branch_id) if user.branch_id else None,
        role=user.role
    )

    return {
        "access_token": token,
        "token_type": "bearer",
        "user_id": str(user.id),
        "organization_id": str(user.organization_id),
        "branch_id": str(user.branch_id) if user.branch_id else None,
        "role": user.role,
        "full_name": user.full_name,
        "email": user.email
    }

@router.post("/pin-login", response_model=Token)
def pin_login(
    payload: PinLoginRequest,
    db: Session = Depends(get_db)
) -> Any:
    """
    Fast PIN-based login for POS cashier/waiter stations on desktop client.
    """
    user = db.query(User).filter(
        User.organization_id == payload.organization_id,
        User.pin_code == payload.pin_code,
        User.is_active == True
    ).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid PIN code for this store station."
        )

    token = create_access_token(
        subject=user.id,
        organization_id=str(user.organization_id),
        branch_id=str(user.branch_id),
        role=user.role
    )

    return {
        "access_token": token,
        "token_type": "bearer",
        "user_id": str(user.id),
        "organization_id": str(user.organization_id),
        "branch_id": str(user.branch_id),
        "role": user.role,
        "full_name": user.full_name,
        "email": user.email
    }

@router.post("/verify-license", response_model=LicenseVerificationResponse)
def verify_license(
    payload: LicenseVerificationRequest,
    db: Session = Depends(get_db)
) -> Any:
    """
    First-run license verification for the Flutter desktop client.
    Validates license key, provisions PowerSync sync tokens, and downloads enabled module list.
    """
    org = db.query(Organization).filter(Organization.license_key == payload.license_key.strip()).first()
    if not org:
        return LicenseVerificationResponse(
            is_valid=False,
            organization_id="",
            organization_name="",
            business_type="",
            branch_id="",
            branch_name="",
            plan="",
            billing_status="invalid",
            enabled_modules=[],
            message="License key not recognized. Please check your activation code."
        )

    validity = LicensingService.check_license_validity(
        billing_status=org.billing_status,
        trial_ends_at=org.trial_ends_at,
        plan=org.plan
    )

    # Get primary or active branch
    primary_branch = db.query(Branch).filter(
        Branch.organization_id == org.id,
        Branch.is_active == True
    ).first()

    branch_id = str(primary_branch.id) if primary_branch else ""
    branch_name = primary_branch.name if primary_branch else "Main Branch"

    # Get enabled modules for this branch
    enabled_modules = []
    if primary_branch:
        branch_mods = db.query(BranchModule).filter(
            BranchModule.branch_id == primary_branch.id,
            BranchModule.is_enabled == True
        ).all()
        enabled_modules = [bm.module_key for bm in branch_mods]

    # Generate PowerSync sync token for the desktop client
    powersync_token = None
    if validity["is_valid"]:
        # Find default branch manager or owner user
        user = db.query(User).filter(User.organization_id == org.id).first()
        user_id = str(user.id) if user else str(org.id)
        role = user.role if user else "cashier"
        
        powersync_token = PowerSyncAuthService.generate_token(
            user_id=user_id,
            organization_id=str(org.id),
            branch_id=branch_id,
            role=role
        )

    return LicenseVerificationResponse(
        is_valid=validity["is_valid"],
        organization_id=str(org.id),
        organization_name=org.name,
        business_type=org.business_type,
        branch_id=branch_id,
        branch_name=branch_name,
        plan=org.plan,
        billing_status=org.billing_status,
        enabled_modules=enabled_modules,
        powersync_token=powersync_token,
        powersync_url=settings.POWERSYNC_URL,
        message=validity.get("message")
    )

@router.get("/powersync-token")
def get_powersync_token(
    user_id: str,
    organization_id: str,
    branch_id: str,
    role: str = "cashier"
) -> Any:
    token = PowerSyncAuthService.generate_token(
        user_id=user_id,
        organization_id=organization_id,
        branch_id=branch_id,
        role=role
    )
    return {
        "token": token,
        "powersync_url": settings.POWERSYNC_URL,
        "expires_in": 86400
    }
