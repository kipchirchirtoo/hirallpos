-- =============================================================================
-- HIRALL POS MIGRATION 012: ROW LEVEL SECURITY (RLS) POLICIES & ENFORCEMENT
-- =============================================================================

-- Helper macro for applying org-level RLS policy
-- When app.current_org_id is set in transaction, only records for that organization are accessible.

-- 1. Organizations
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_organizations ON organizations;
CREATE POLICY rls_organizations ON organizations
    FOR ALL
    USING (get_current_org_id() IS NULL OR id = get_current_org_id())
    WITH CHECK (get_current_org_id() IS NULL OR id = get_current_org_id());

-- 2. Storage & Assets
ALTER TABLE org_storage_buckets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_org_storage_buckets ON org_storage_buckets;
CREATE POLICY rls_org_storage_buckets ON org_storage_buckets
    FOR ALL
    USING (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
    WITH CHECK (get_current_org_id() IS NULL OR organization_id = get_current_org_id());

ALTER TABLE org_assets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_org_assets ON org_assets;
CREATE POLICY rls_org_assets ON org_assets
    FOR ALL
    USING (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
    WITH CHECK (get_current_org_id() IS NULL OR organization_id = get_current_org_id());

-- 3. Branches & Tills
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_branches ON branches;
CREATE POLICY rls_branches ON branches
    FOR ALL
    USING (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
    WITH CHECK (get_current_org_id() IS NULL OR organization_id = get_current_org_id());

ALTER TABLE till_registers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_till_registers ON till_registers;
CREATE POLICY rls_till_registers ON till_registers
    FOR ALL
    USING (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    )
    WITH CHECK (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    );

-- 4. Users & Assignments
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_users ON users;
CREATE POLICY rls_users ON users
    FOR ALL
    USING (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
    WITH CHECK (get_current_org_id() IS NULL OR organization_id = get_current_org_id());

ALTER TABLE user_branch_assignments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_user_branch_assignments ON user_branch_assignments;
CREATE POLICY rls_user_branch_assignments ON user_branch_assignments
    FOR ALL
    USING (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
    WITH CHECK (get_current_org_id() IS NULL OR organization_id = get_current_org_id());

-- 5. Branch Modules
ALTER TABLE branch_modules ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_branch_modules ON branch_modules;
CREATE POLICY rls_branch_modules ON branch_modules
    FOR ALL
    USING (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    )
    WITH CHECK (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    );

-- 6. Product Catalog
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_categories ON categories;
CREATE POLICY rls_categories ON categories
    FOR ALL
    USING (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
    WITH CHECK (get_current_org_id() IS NULL OR organization_id = get_current_org_id());

ALTER TABLE products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_products ON products;
CREATE POLICY rls_products ON products
    FOR ALL
    USING (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
    WITH CHECK (get_current_org_id() IS NULL OR organization_id = get_current_org_id());

ALTER TABLE product_barcode_aliases ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_product_barcode_aliases ON product_barcode_aliases;
CREATE POLICY rls_product_barcode_aliases ON product_barcode_aliases
    FOR ALL
    USING (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
    WITH CHECK (get_current_org_id() IS NULL OR organization_id = get_current_org_id());

ALTER TABLE product_pricing_tiers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_product_pricing_tiers ON product_pricing_tiers;
CREATE POLICY rls_product_pricing_tiers ON product_pricing_tiers
    FOR ALL
    USING (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
    WITH CHECK (get_current_org_id() IS NULL OR organization_id = get_current_org_id());

-- 7. Inventory & Transfers
ALTER TABLE branch_inventory ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_branch_inventory ON branch_inventory;
CREATE POLICY rls_branch_inventory ON branch_inventory
    FOR ALL
    USING (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    )
    WITH CHECK (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    );

ALTER TABLE goods_received_notes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_goods_received_notes ON goods_received_notes;
CREATE POLICY rls_goods_received_notes ON goods_received_notes
    FOR ALL
    USING (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
    WITH CHECK (get_current_org_id() IS NULL OR organization_id = get_current_org_id());

ALTER TABLE stock_transfers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_stock_transfers ON stock_transfers;
CREATE POLICY rls_stock_transfers ON stock_transfers
    FOR ALL
    USING (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
    WITH CHECK (get_current_org_id() IS NULL OR organization_id = get_current_org_id());

ALTER TABLE stock_adjustments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_stock_adjustments ON stock_adjustments;
CREATE POLICY rls_stock_adjustments ON stock_adjustments
    FOR ALL
    USING (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    )
    WITH CHECK (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    );

-- 8. Sales, Payments & Supervisor Audits
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_sales ON sales;
CREATE POLICY rls_sales ON sales
    FOR ALL
    USING (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    )
    WITH CHECK (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    );

ALTER TABLE payment_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_payment_transactions ON payment_transactions;
CREATE POLICY rls_payment_transactions ON payment_transactions
    FOR ALL
    USING (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
    WITH CHECK (get_current_org_id() IS NULL OR organization_id = get_current_org_id());

ALTER TABLE supervisor_void_audits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_supervisor_void_audits ON supervisor_void_audits;
CREATE POLICY rls_supervisor_void_audits ON supervisor_void_audits
    FOR ALL
    USING (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    )
    WITH CHECK (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    );

-- 9. Shifts & Expenses
ALTER TABLE cashier_shifts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_cashier_shifts ON cashier_shifts;
CREATE POLICY rls_cashier_shifts ON cashier_shifts
    FOR ALL
    USING (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    )
    WITH CHECK (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    );

ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_expenses ON expenses;
CREATE POLICY rls_expenses ON expenses
    FOR ALL
    USING (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    )
    WITH CHECK (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    );

ALTER TABLE daily_pl_summaries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_daily_pl_summaries ON daily_pl_summaries;
CREATE POLICY rls_daily_pl_summaries ON daily_pl_summaries
    FOR ALL
    USING (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
    WITH CHECK (get_current_org_id() IS NULL OR organization_id = get_current_org_id());

-- 10. Hospitality & Waiter
ALTER TABLE restaurant_tables ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_restaurant_tables ON restaurant_tables;
CREATE POLICY rls_restaurant_tables ON restaurant_tables
    FOR ALL
    USING (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    )
    WITH CHECK (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    );

ALTER TABLE kitchen_orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_kitchen_orders ON kitchen_orders;
CREATE POLICY rls_kitchen_orders ON kitchen_orders
    FOR ALL
    USING (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    )
    WITH CHECK (
        (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
        AND (get_current_branch_id() IS NULL OR branch_id = get_current_branch_id())
    );

-- 11. Receipt Templates
ALTER TABLE receipt_templates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rls_receipt_templates ON receipt_templates;
CREATE POLICY rls_receipt_templates ON receipt_templates
    FOR ALL
    USING (get_current_org_id() IS NULL OR organization_id = get_current_org_id())
    WITH CHECK (get_current_org_id() IS NULL OR organization_id = get_current_org_id());
