-- =============================================================================
-- HIRALL POS MIGRATION 013: POWERSYNC LOGICAL REPLICATION PUBLICATION
-- =============================================================================

-- 1. Ensure Replica Identity for Real-time Update/Delete tracking
ALTER TABLE organizations REPLICA IDENTITY DEFAULT;
ALTER TABLE branches REPLICA IDENTITY DEFAULT;
ALTER TABLE till_registers REPLICA IDENTITY DEFAULT;
ALTER TABLE users REPLICA IDENTITY DEFAULT;
ALTER TABLE modules REPLICA IDENTITY DEFAULT;
ALTER TABLE branch_modules REPLICA IDENTITY DEFAULT;
ALTER TABLE categories REPLICA IDENTITY DEFAULT;
ALTER TABLE products REPLICA IDENTITY DEFAULT;
ALTER TABLE product_barcode_aliases REPLICA IDENTITY DEFAULT;
ALTER TABLE product_pricing_tiers REPLICA IDENTITY DEFAULT;
ALTER TABLE branch_inventory REPLICA IDENTITY DEFAULT;
ALTER TABLE sales REPLICA IDENTITY DEFAULT;
ALTER TABLE sale_items REPLICA IDENTITY DEFAULT;
ALTER TABLE payment_transactions REPLICA IDENTITY DEFAULT;
ALTER TABLE supervisor_void_audits REPLICA IDENTITY DEFAULT;
ALTER TABLE cashier_shifts REPLICA IDENTITY DEFAULT;
ALTER TABLE till_reconciliations REPLICA IDENTITY DEFAULT;
ALTER TABLE expenses REPLICA IDENTITY DEFAULT;
ALTER TABLE restaurant_tables REPLICA IDENTITY DEFAULT;
ALTER TABLE kitchen_orders REPLICA IDENTITY DEFAULT;
ALTER TABLE kitchen_order_items REPLICA IDENTITY DEFAULT;
ALTER TABLE receipt_templates REPLICA IDENTITY DEFAULT;

-- 2. Create Publication for PowerSync replication
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'powersync_publication') THEN
        CREATE PUBLICATION powersync_publication FOR ALL TABLES;
    END IF;
END
$$;
