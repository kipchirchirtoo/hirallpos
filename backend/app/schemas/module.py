from typing import Optional, Dict, Any, List
from pydantic import BaseModel

class ModuleOut(BaseModel):
    key: str
    display_name: str
    description: Optional[str] = None

    class Config:
        from_attributes = True

class BranchModuleUpdate(BaseModel):
    is_enabled: bool
    config: Optional[Dict[str, Any]] = None

class BusinessTypeInfo(BaseModel):
    business_type: str
    label: str
    description: str
    default_modules: List[str]
