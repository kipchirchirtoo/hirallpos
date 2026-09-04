from typing import Optional, List, Dict, Any
from pydantic import BaseModel
from uuid import UUID
from datetime import datetime

class BranchBase(BaseModel):
    name: str
    location: Optional[str] = None
    till_number: Optional[str] = None

class BranchCreate(BranchBase):
    pass

class BranchUpdate(BaseModel):
    name: Optional[str] = None
    location: Optional[str] = None
    till_number: Optional[str] = None
    is_active: Optional[bool] = None

class BranchModuleInfo(BaseModel):
    module_key: str
    display_name: str
    is_enabled: bool
    config: Dict[str, Any] = {}

class BranchOut(BranchBase):
    id: UUID
    organization_id: UUID
    is_active: bool
    created_at: datetime
    modules: Optional[List[BranchModuleInfo]] = []

    class Config:
        from_attributes = True
