# Hirall POS - Web Onboarding & Cloud Admin Portal

This is the standalone, web-based merchant onboarding and cloud administration console for the **Hirall POS Platform**.

---

## 🏛️ Platform Architecture

```
                  ┌────────────────────────────────────────────────────────┐
                  │   WEB ONBOARDING & CLOUD ADMIN PORTAL (Web-Based)      │
                  │   • Deployed at: app.hirall.co / admin.hirall.co       │
                  │   • 5-Step Merchant Self-Service Onboarding Wizard     │
                  │   • Global License Key Generation & Provisioning       │
                  │   • Enterprise Multi-Branch & Till Lane Management     │
                  │   • Master SKU Catalog & Global Price Policies         │
                  └──────────────────────────┬─────────────────────────────┘
                                             │ (REST API & JWT)
                                             ▼
                  ┌────────────────────────────────────────────────────────┐
                  │            SHARED FASTAPI BACKEND & POSTGRES RDS       │
                  │   • FastAPI REST Endpoints (/api/v1)                   │
                  │   • PostgreSQL with Tenant Row-Level Security (RLS)    │
                  │   • PowerSync Partition Replication Engine             │
                  └──────────────────────────▲─────────────────────────────┘
                                             │ (License Activation & Offline Sync)
                                             │
                  ┌──────────────────────────┴─────────────────────────────┐
                  │      FLUTTER DESKTOP CLIENTS (In-Store POS Registers)  │
                  │   • Linux / Windows / Android Cashier Terminals        │
                  │   • High-Speed USB/HID Barcode Scanning                │
                  │   • Offline-First Drift SQLite & PowerSync             │
                  │   • 80mm Thermal Receipts & M-Pesa STK Push            │
                  └────────────────────────────────────────────────────────┘
```

---

## 🚀 Running Locally

### Option 1: Using Python Simple Server
```bash
cd web-admin
python3 -m http.server 3000
```
Open [http://localhost:3000](http://localhost:3000) in your web browser.

### Option 2: Using Node `npx serve`
```bash
cd web-admin
npx serve -l 3000
```

---

## 🌐 Deploying to Production

This portal is 100% static HTML5/CSS3/Vanilla JS with zero build step required:
- **Vercel**: Run `vercel deploy` inside the `web-admin/` folder.
- **Netlify**: Drag and drop the `web-admin/` folder or link GitHub repo.
- **Cloudflare Pages**: Connect repo, set build output directory to `web-admin`.
- **Nginx / S3 + CloudFront**: Copy the contents of `web-admin/` to your web root.

---

## 🔑 Backend Integration
The portal automatically connects to the FastAPI backend at:
- **Local Development**: `http://127.0.0.1:8000/api/v1`
- **Production Cloud**: Uses relative `/api/v1` or configured `API_BASE_URL`.
