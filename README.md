# Hirall POS — Multi-Org, Multi-Branch, Multi-Module Offline-First POS Platform

An enterprise-grade, offline-first Point of Sale platform architected for multi-organization and multi-branch operations across supermarkets, retail stores, restaurants, bars/clubs, laundries, spas, and service outlets.

---

## Architecture Overview

```
                         ┌─────────────────────────────┐
                         │   FastAPI Backend             │
                         │   (ECS Fargate / AWS)         │
                         │   - JWT Auth & RLS Context    │
                         │   - Org/Branch/User CRUD      │
                         │   - M-Pesa STK (Daraja/PayHero)│
                         │   - PowerSync RS256 Tokens    │
                         └──────────────┬────────────────┘
                                        │
                                        ▼
                         ┌─────────────────────────────┐
                         │   PostgreSQL (AWS RDS)        │  ← Single source of truth
                         │   RLS-isolated per org         │
                         └──────────────┬────────────────┘
                                        │ logical replication (wal_level=logical)
                                        ▼
                         ┌─────────────────────────────┐
                         │   PowerSync Service            │  ← Sync engine scoped by branch
                         └──────────────┬────────────────┘
                                        │
              ┌─────────────────────────┼─────────────────────────┐
              ▼                         ▼                         ▼
   ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
   │ Flutter Desktop   │      │ Flutter Desktop   │      │ Flutter Desktop   │
   │ Branch A (Retail) │      │ Branch B (Rest.)  │      │ Branch C (Spa)    │
   │ Local SQLite/Drift│      │ Local SQLite/Drift│      │ Local SQLite/Drift│
   └─────────────────┘      └─────────────────┘      └─────────────────┘
```

- **Frontend Client (100% Flutter):** Desktop application handles the 4-step Organization Onboarding Wizard, License Activation, Super-Admin overview, and all 6 POS operational modules (`Cashier`, `Storekeeping`, `POS Outlets`, `Accounting`, `Waiter`, `Management & HR`).
- **Database (PostgreSQL on AWS RDS):** Native Row-Level Security (RLS) enforcing strict tenant data isolation.
- **Offline Sync (PowerSync):** Streams logical replication changes down to client SQLite/Drift databases partitioned by `organization_id` and `branch_id`.
- **Backend API (FastAPI):** Python 3.11+, SQLAlchemy 2.0, Alembic migrations, M-Pesa Daraja/PayHero STK push, and RS256 PowerSync token generation.

---

## Directory Structure

```
hirall-pos/
├── backend/                   # FastAPI Backend & PostgreSQL RLS
│   ├── app/
│   │   ├── api/v1/endpoints/  # Auth, Orgs, Branches, Modules, Billing (M-Pesa), POS
│   │   ├── core/              # Config, Security (JWT), DB Session, RLS Context
│   │   ├── models/            # SQLAlchemy Models (Org, Branch, Modules, Users, Sales, etc.)
│   │   ├── schemas/           # Pydantic v2 validation schemas
│   │   ├── services/          # M-Pesa Daraja/PayHero, Licensing, PowerSync Auth
│   │   └── main.py            # FastAPI entrypoint with CORS & startup seeder
│   ├── alembic/               # Database migrations & RLS policies
│   ├── requirements.txt
│   └── Dockerfile
├── desktop-app/               # Flutter Desktop Client (100% Flutter UI)
│   ├── lib/
│   │   ├── core/              # Theme, Constants, SQLite/Drift Database, PowerSync Client
│   │   ├── features/
│   │   │   ├── onboarding/    # 4-Step Registration Wizard (Info -> Type -> M-Pesa -> Activation)
│   │   │   ├── activation/    # License Activation Key verification screen
│   │   │   ├── shell/         # Dynamic Sidebar gated by branch_modules entitlements
│   │   │   ├── cashier/       # POS Checkout, Barcode scanning, M-Pesa STK, Thermal Receipts
│   │   │   ├── storekeeping/  # Inventory levels, Stock Receiving, Inter-Branch Transfers
│   │   │   ├── outlets/       # Branch directory, Till codes, Multi-branch switcher
│   │   │   ├── accounting/    # Shift Till Reconciliation, Expense Logger, P&L, VAT 16%
│   │   │   ├── waiter/        # Table floor plan, KOT dispatcher, Split bills
│   │   │   ├── hr/            # Staff directory, PIN assignment, Shift attendance logs
│   │   │   └── admin/         # Super-admin settings, live module toggles, license copy
│   │   └── main.dart          # Riverpod entrypoint
│   └── pubspec.yaml
├── powersync/                 # PowerSync Sync Layer
│   ├── sync_rules.yaml        # Tenant & branch-scoped partition rules
│   └── replication_setup.sql  # PostgreSQL publication and replication slot scripts
├── docker-compose.yml         # Dev cluster (PostgreSQL + FastAPI)
└── README.md
```

---

## Getting Started

### 1. Launch Backend & PostgreSQL
```bash
cd hirall-pos
docker-compose up -d
```
Or run FastAPI locally with Python:
```bash
cd backend
python3 -m venv venv
./venv/bin/pip install -r requirements.txt
./venv/bin/uvicorn app.main:app --reload --port 8000
```
Backend API docs will be live at: `http://localhost:8000/docs`

### 2. Launch Flutter Desktop Client
```bash
cd desktop-app
flutter pub get
flutter run -d linux # or -d windows / -d macos
```

---

## The 6 POS Modules Matrix

| Module | Features & Capabilities | Supported Business Types |
|---|---|---|
| **Cashier** | Barcode scan, Cart drawer, 16% VAT, Cash with change calculator, M-Pesa STK push, Thermal 80mm receipts, Offline queue | All (`supermarket`, `retail`, `restaurant`, `bar_club`, `laundry`, `spa`, `car_wash`) |
| **Storekeeping** | Stock intake/receiving, Low-stock alerts, Inter-branch stock transfers, Cost & Margin tracking | `supermarket`, `retail`, `restaurant`, `bar_club` |
| **POS Outlets** | Multi-branch switcher, Till setup, Branch receipt header/footer, Active module status | All |
| **Accounting** | Shift opening/closing float count, Cash vs M-Pesa variance, Daily expense logging, Branch P&L | All |
| **Waiter** | Interactive restaurant floor plan, Table status (Available/Occupied/Billing/Reserved), Kitchen Order Tickets (KOT), Bill split | `restaurant`, `bar_club` |
| **Management & HR**| Staff roster, 4-digit station PINs, Role permissions, Shift clock-in/out attendance tracking | `supermarket`, `restaurant`, `laundry`, `spa`, `car_wash` |
