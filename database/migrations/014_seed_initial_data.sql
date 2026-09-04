-- =============================================================================
-- HIRALL POS MIGRATION 014: SYSTEM SEED DATA & PRESETS
-- =============================================================================

-- 1. Standard System Roles
INSERT INTO roles (key, name, description, hierarchy_level) VALUES
    ('owner', 'Organization Owner / Merchant Admin', 'Full administrative authority over entire organization, branches, billing, and system settings.', 100),
    ('branch_manager', 'Branch General Supervisor / Manager', 'Full control over branch operations, cashier shifts, inventory transfers, and supervisor void approvals.', 80),
    ('accountant', 'Branch Accountant / Auditor', 'Access to financial reports, P&L, petty cash expenses, and till reconciliation audits.', 60),
    ('storekeeper', 'Storekeeper / Inventory Officer', 'Access to goods receiving, supplier GRN, stock taking, and inter-branch dispatch.', 40),
    ('cashier', 'Counter Till Cashier', 'Point of sale checkout, barcode scanning, receipt printing, and cash/M-Pesa payment collection.', 20),
    ('waiter', 'Restaurant Floor Waiter', 'Table order entry, kitchen order ticket (KOT) dispatch, and guest bill presentation.', 10)
ON CONFLICT (key) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    hierarchy_level = EXCLUDED.hierarchy_level;

-- 2. System Permissions
INSERT INTO permissions (key, category, name, description) VALUES
    ('pos:checkout', 'POS', 'Process Sale Checkout', 'Scan barcodes and process payment tenders at the till register.'),
    ('pos:void_item', 'POS', 'Void Cart Line Item', 'Remove or cancel scanned items from active customer cart.'),
    ('pos:void_transaction', 'POS', 'Void Full Sale Transaction', 'Cancel entire sale ticket before or after payment.'),
    ('pos:apply_discount', 'POS', 'Apply Manual Line Discount', 'Apply percentage or fixed price markdowns.'),
    ('inventory:view', 'Inventory', 'View Stock Levels', 'Check real-time branch and central warehouse quantities.'),
    ('inventory:receive', 'Inventory', 'Receive Supplier Deliveries', 'Create Goods Received Notes (GRN) from vendors.'),
    ('inventory:transfer', 'Inventory', 'Initiate Stock Transfers', 'Dispatch stock to other branch locations.'),
    ('inventory:adjust', 'Inventory', 'Perform Stock Adjustments', 'Log spoilage, breakage, or audit shrinkage.'),
    ('finance:view_pl', 'Finance', 'View Branch P&L', 'Analyze gross sales, net profit, margins, and VAT summaries.'),
    ('finance:reconcile', 'Finance', 'Perform Till Reconciliation', 'Conduct end-of-shift Z-report and cash drawer balancing.'),
    ('finance:log_expense', 'Finance', 'Log Petty Cash Expense', 'Record operational expenses and upload receipt vouchers.'),
    ('admin:manage_staff', 'Admin', 'Manage Staff & PINs', 'Create cashier profiles, assign roles, and set 4-digit station PINs.'),
    ('admin:manage_branches', 'Admin', 'Configure Branches & Tills', 'Provision branch outlets and assign till terminal hardware.'),
    ('admin:receipt_designer', 'Admin', 'Customize Thermal Receipts', 'Upload logos, configure festive greetings, adverts, and duplex rules.')
ON CONFLICT (key) DO NOTHING;

-- 3. Role-Permission Defaults
-- Owner gets all permissions
INSERT INTO role_permissions (role_key, permission_key)
SELECT 'owner', key FROM permissions
ON CONFLICT DO NOTHING;

-- Branch Manager permissions
INSERT INTO role_permissions (role_key, permission_key) VALUES
    ('branch_manager', 'pos:checkout'),
    ('branch_manager', 'pos:void_item'),
    ('branch_manager', 'pos:void_transaction'),
    ('branch_manager', 'pos:apply_discount'),
    ('branch_manager', 'inventory:view'),
    ('branch_manager', 'inventory:receive'),
    ('branch_manager', 'inventory:transfer'),
    ('branch_manager', 'inventory:adjust'),
    ('branch_manager', 'finance:view_pl'),
    ('branch_manager', 'finance:reconcile'),
    ('branch_manager', 'finance:log_expense'),
    ('branch_manager', 'admin:manage_staff')
ON CONFLICT DO NOTHING;

-- Cashier permissions
INSERT INTO role_permissions (role_key, permission_key) VALUES
    ('cashier', 'pos:checkout')
ON CONFLICT DO NOTHING;

-- Storekeeper permissions
INSERT INTO role_permissions (role_key, permission_key) VALUES
    ('storekeeper', 'inventory:view'),
    ('storekeeper', 'inventory:receive'),
    ('storekeeper', 'inventory:transfer'),
    ('storekeeper', 'inventory:adjust')
ON CONFLICT DO NOTHING;

-- 4. Master Operational Modules Catalog
INSERT INTO modules (key, display_name, description, icon_name, category) VALUES
    ('cashier', 'Cashier & POS Checkout', 'Product search, barcode scanning, cart management, receipt printing, cash/M-Pesa/card payments, and offline sale queueing.', 'shopping-cart', 'core'),
    ('storekeeping', 'Storekeeping & Inventory', 'Stock receiving, inter-branch transfers, low-stock threshold alerts, and supplier catalog.', 'boxes', 'retail'),
    ('pos_outlets', 'POS Outlets & Branches', 'Branch directory, till number setup, active module entitlements, and org performance comparison.', 'store', 'core'),
    ('accounting', 'Accounting & Finance', 'Daily till reconciliation, expense logging, branch P&L, and basic VAT tax summaries.', 'landmark', 'finance'),
    ('waiter', 'Waiter & Table Management', 'Table status (open/served/paid), kitchen order tickets (KOT), split bill, and table transfers.', 'utensils', 'hospitality'),
    ('hr_management', 'Management & HR', 'Staff directory, role and PIN assignments, shift scheduling, and attendance clock-in/out.', 'users', 'core')
ON CONFLICT (key) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name,
    category = EXCLUDED.category;

-- 5. Business Type Default Module Matrix
INSERT INTO business_type_defaults (business_type, module_key) VALUES
    -- Supermarket Edition
    ('supermarket', 'cashier'),
    ('supermarket', 'storekeeping'),
    ('supermarket', 'pos_outlets'),
    ('supermarket', 'accounting'),
    ('supermarket', 'hr_management'),
    
    -- Retail Boutique / Hardware
    ('retail', 'cashier'),
    ('retail', 'storekeeping'),
    ('retail', 'pos_outlets'),
    ('retail', 'accounting'),
    
    -- Restaurant & Café
    ('restaurant', 'cashier'),
    ('restaurant', 'waiter'),
    ('restaurant', 'storekeeping'),
    ('restaurant', 'accounting'),
    ('restaurant', 'hr_management'),
    
    -- Bar & Nightclub
    ('bar_club', 'cashier'),
    ('bar_club', 'waiter'),
    ('bar_club', 'accounting'),
    ('bar_club', 'hr_management'),
    
    -- Laundromat
    ('laundry', 'cashier'),
    ('laundry', 'accounting'),
    ('laundry', 'pos_outlets'),
    
    -- Spa & Salon
    ('spa', 'cashier'),
    ('spa', 'hr_management'),
    ('spa', 'accounting')
ON CONFLICT DO NOTHING;

-- 6. Default Global Tax Rates (KRA Standard Classifications)
INSERT INTO tax_rates (id, organization_id, name, rate_percent, is_inclusive, is_default, kra_tax_code) VALUES
    ('00000000-0000-0000-0000-000000000001', NULL, 'Standard VAT (16%)', 16.00, true, true, 'A'),
    ('00000000-0000-0000-0000-000000000002', NULL, 'Zero-Rated (0%)', 0.00, true, false, 'B'),
    ('00000000-0000-0000-0000-000000000003', NULL, 'Exempt (0%)', 0.00, false, false, 'C')
ON CONFLICT DO NOTHING;
