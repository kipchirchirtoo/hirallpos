import logging
from sqlalchemy.orm import Session
from app.models.module import Module, BusinessTypeDefault
from app.api.v1.endpoints.modules import BUSINESS_TYPE_DEFINITIONS

logger = logging.getLogger(__name__)

# Fixed Module Catalog
MODULE_CATALOG = [
    {
        "key": "cashier",
        "display_name": "Cashier & POS Checkout",
        "description": "Product search, barcode scanning, cart management, receipt printing, cash/M-Pesa/card payments, and offline sale queueing."
    },
    {
        "key": "storekeeping",
        "display_name": "Storekeeping & Inventory",
        "description": "Stock receiving, inter-branch transfers, low-stock threshold alerts, and supplier catalog."
    },
    {
        "key": "pos_outlets",
        "display_name": "POS Outlets & Branches",
        "description": "Branch directory, till number setup, active module entitlements, and org performance comparison."
    },
    {
        "key": "accounting",
        "display_name": "Accounting & Finance",
        "description": "Daily till reconciliation, expense logging, branch P&L, and basic VAT tax summaries."
    },
    {
        "key": "waiter",
        "display_name": "Waiter & Table Management",
        "description": "Table status (open/served/paid), kitchen order tickets (KOT), split bill, and table transfers."
    },
    {
        "key": "hr_management",
        "display_name": "Management & HR",
        "description": "Staff directory, role and PIN assignments, shift scheduling, and attendance clock-in/out."
    },
]

def init_db(db: Session) -> None:
    # 1. Seed Modules
    for mod_data in MODULE_CATALOG:
        existing = db.query(Module).filter(Module.key == mod_data["key"]).first()
        if not existing:
            mod = Module(
                key=mod_data["key"],
                display_name=mod_data["display_name"],
                description=mod_data["description"]
            )
            db.add(mod)
    db.flush()

    # 2. Seed Business Type Defaults
    for b_type in BUSINESS_TYPE_DEFINITIONS:
        for mod_key in b_type["default_modules"]:
            existing_def = db.query(BusinessTypeDefault).filter(
                BusinessTypeDefault.business_type == b_type["business_type"],
                BusinessTypeDefault.module_key == mod_key
            ).first()
            if not existing_def:
                btd = BusinessTypeDefault(
                    business_type=b_type["business_type"],
                    module_key=mod_key
                )
                db.add(btd)
    
    db.commit()
    logger.info("Database modules and business type defaults seeded successfully.")
