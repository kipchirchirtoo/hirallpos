# Hirall POS — Enterprise Database & Migration System

This directory contains the production-grade PostgreSQL database schema migrations, multi-tenant Row Level Security (RLS) enforcement policies, RBAC access controls, secure storage asset catalog, and PowerSync offline-first replication definitions for **Hirall POS**.

---

## 🏗 Architectural Blueprint

```
hirall-pos/database/
├── README.md                           # Database architecture & runbook
├── migrate.py                          # Automated migration execution engine
└── migrations/
    ├── 001_extensions_and_helpers.sql          # UUID, timestamps & tenant context helpers
    ├── 002_organizations_and_storage.sql      # Multi-org isolation, buckets & asset uploads
    ├── 003_branches_and_tills.sql              # Multi-branch hierarchy & till checkout lanes
    ├── 004_users_and_rbac.sql                  # Multi-user auth, RBAC permissions & station PINs
    ├── 005_modules_and_entitlements.sql        # 6 POS operational modules & branch entitlements
    ├── 006_catalog_and_pricing.sql             # Categories, products, barcodes & pricing tiers
    ├── 007_inventory_and_transfers.sql         # Multi-branch stock, GRN deliveries & transfers
    ├── 008_sales_and_checkout.sql              # Sales, tenders, M-Pesa STK & supervisor voids
    ├── 009_shifts_and_accounting.sql           # Cashier shifts, till balancing & branch P&L
    ├── 010_hospitality_and_waiter.sql          # Restaurant tables, dining sessions & KOTs
    ├── 011_receipt_customizer_and_adverts.sql  # Thermal receipt templates, duplex & holiday banners
    ├── 012_row_level_security_rls.sql          # PostgreSQL RLS policies & tenant filters
    ├── 013_powersync_publication.sql           # PowerSync logical replication publication
    └── 014_seed_initial_data.sql               # Default roles, permissions, modules & tax rates
```

---

## 🔒 Core Architecture Rules Enforced

### 1. Multi-Tenant Organization Isolation (`organizations`)
- Every table is strictly partitioned by `organization_id` (`UUID`).
- Organizations have dedicated subdomains, trading names, KRA tax PINs, license keys, and billing plans.

### 2. Multi-Branch Hierarchy (`branches` & `till_registers`)
- Support for Central Headquarters and unlimited branch outlets.
- Each branch has its own physical address, M-Pesa paybill, and multiple assigned till registers (e.g. `TILL-01`, `EXPRESS-01`).

### 3. Multi-User & Granular RBAC (`users`, `roles`, `permissions`)
- Built-in roles: `owner`, `branch_manager`, `accountant`, `storekeeper`, `cashier`, `waiter`.
- **4-Digit Station PIN**: Fast switch and till unlocking on POS hardware registers.
- **Supervisor Badge Scanning**: Scanned barcode badges (`SUP-9901`) for authorization.
- **Supervisor Void Audit**: Security records logged on every voided item or canceled transaction.

### 4. Branch-Specific Operational Modules (`branch_modules`)
- Dynamically toggle POS capabilities per branch:
  1. `cashier`: Point of Sale Barcode Scanning & Checkout
  2. `storekeeping`: Inventory Receiving & Inter-Branch Stock Transfers
  3. `pos_outlets`: Multi-Branch & Till Hardware Configuration
  4. `accounting`: Till Reconciliations, Petty Cash & Branch P&L
  5. `waiter`: Restaurant Table Management & Kitchen Order Tickets (KOT)
  6. `hr_management`: Staff Roster, Shift Tracking & Station PINs

### 5. Secure Object Storage for Logos & Assets (`org_storage_buckets` & `org_assets`)
- Dedicated storage buckets partitioned per tenant:
  - `logos`: High-resolution and 203 DPI monochrome thermal POS printhead logos.
  - `receipts`: Expense receipt image vouchers and fiscal records.
  - `marketing`: Promotional banners, discount coupon artwork, and partner advert graphics.
- Enforces MIME type whitelisting (`image/png`, `image/jpeg`, `image/svg+xml`, `image/webp`) and file size quotas (5MB default).

### 6. Thermal Receipt Customizer & Double-Sided Printing (`receipt_templates`)
- Real-time thermal layout configuration for 80mm standard and 58mm mobile roll printers.
- **Front of Receipt**: Store name, physical address, KRA Tax PIN, line items, 16% VAT, M-Pesa code, Code-128 barcode.
- **Back of Receipt (Duplex)**: Terms of sale, promotional voucher coupons, customer survey QR code, partner advert space.
- **Holiday & Seasonal Greetings**: Quick presets (Christmas, Eid, Jamhuri, Black Friday, Easter) with embellishment borders.

### 7. PostgreSQL Row Level Security (RLS) Enforcement
- PostgreSQL engine-level RLS enabled across all tenant-scoped tables:
  ```sql
  SET LOCAL app.current_org_id = '<organization-uuid>';
  SET LOCAL app.current_branch_id = '<branch-uuid>';
  ```
- Guaranteed protection against cross-tenant data leakage.

### 8. PowerSync Offline Replication
- Real-time logical replication publication `powersync_publication` keeping Flutter desktop clients synced offline with Amazon RDS.

---

## ⚡ How to Run Migrations

### Check Migration Status:
```bash
python database/migrate.py status
```

### Apply Pending Migrations:
```bash
python database/migrate.py up
```
