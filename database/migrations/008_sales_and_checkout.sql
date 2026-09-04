-- =============================================================================
-- HIRALL POS MIGRATION 008: SALES, CHECKOUT, PAYMENTS & SUPERVISOR VOID AUDITS
-- =============================================================================

-- 1. Sales Master Transactions Table
CREATE TABLE IF NOT EXISTS sales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    till_id UUID REFERENCES till_registers(id) ON DELETE SET NULL,
    cashier_id UUID REFERENCES users(id) ON DELETE SET NULL,
    shift_id UUID,
    receipt_number VARCHAR(100) NOT NULL,
    customer_name VARCHAR(255),
    customer_phone VARCHAR(50),
    customer_kra_pin VARCHAR(50),
    subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    tax_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    amount_paid NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    change_given NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    payment_method VARCHAR(50) NOT NULL DEFAULT 'cash', -- cash | mpesa | card | split | voucher
    payment_status VARCHAR(50) NOT NULL DEFAULT 'completed', -- completed | voided | refunded | pending
    is_voided BOOLEAN DEFAULT false,
    void_reason TEXT,
    sync_status VARCHAR(50) DEFAULT 'synced', -- synced | pending | offline_queued
    kra_etims_control_code VARCHAR(100),
    kra_qr_data TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_org_receipt_number UNIQUE (organization_id, receipt_number)
);

ALTER TABLE sales ADD COLUMN IF NOT EXISTS till_id UUID REFERENCES till_registers(id) ON DELETE SET NULL;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS cashier_id UUID REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS shift_id UUID;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS customer_name VARCHAR(255);
ALTER TABLE sales ADD COLUMN IF NOT EXISTS customer_phone VARCHAR(50);
ALTER TABLE sales ADD COLUMN IF NOT EXISTS customer_kra_pin VARCHAR(50);
ALTER TABLE sales ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(12, 2) DEFAULT 0.00;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS amount_paid NUMERIC(12, 2) DEFAULT 0.00;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS change_given NUMERIC(12, 2) DEFAULT 0.00;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS is_voided BOOLEAN DEFAULT false;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS void_reason TEXT;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS sync_status VARCHAR(50) DEFAULT 'synced';
ALTER TABLE sales ADD COLUMN IF NOT EXISTS kra_etims_control_code VARCHAR(100);
ALTER TABLE sales ADD COLUMN IF NOT EXISTS kra_qr_data TEXT;

CREATE INDEX IF NOT EXISTS idx_sales_org ON sales(organization_id);
CREATE INDEX IF NOT EXISTS idx_sales_branch ON sales(branch_id);
CREATE INDEX IF NOT EXISTS idx_sales_cashier ON sales(cashier_id);
CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales(branch_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sales_receipt ON sales(organization_id, receipt_number);

-- 2. Sale Itemized Line Items
CREATE TABLE IF NOT EXISTS sale_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE SET NULL,
    product_name VARCHAR(255) NOT NULL,
    barcode VARCHAR(100),
    unit_price NUMERIC(12, 2) NOT NULL,
    quantity NUMERIC(12, 3) NOT NULL DEFAULT 1.000,
    tax_rate_percent NUMERIC(5, 2) NOT NULL DEFAULT 16.00,
    tax_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    line_total NUMERIC(12, 2) NOT NULL,
    is_voided BOOLEAN DEFAULT false,
    void_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_product ON sale_items(product_id);

-- 3. Payment Transactions (Tender Multi-Split: Cash, M-Pesa, Card)
CREATE TABLE IF NOT EXISTS payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    payment_method VARCHAR(50) NOT NULL, -- cash | mpesa | visa_card | mastercard | voucher
    amount NUMERIC(12, 2) NOT NULL,
    reference_code VARCHAR(100), -- M-Pesa Code (e.g. QKJ8812903) or Card Auth Ref
    status VARCHAR(50) NOT NULL DEFAULT 'completed', -- completed | failed | pending
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_payment_transactions_sale ON payment_transactions(sale_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_ref ON payment_transactions(reference_code);

-- 4. Safaricom M-Pesa Daraja STK Push Logs
CREATE TABLE IF NOT EXISTS mpesa_daraja_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    sale_id UUID REFERENCES sales(id) ON DELETE SET NULL,
    merchant_request_id VARCHAR(100),
    checkout_request_id VARCHAR(100) UNIQUE,
    phone_number VARCHAR(50) NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    mpesa_receipt_number VARCHAR(100),
    result_code INT,
    result_desc TEXT,
    raw_payload JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_mpesa_daraja_logs_checkout ON mpesa_daraja_logs(checkout_request_id);
CREATE INDEX IF NOT EXISTS idx_mpesa_daraja_logs_receipt ON mpesa_daraja_logs(mpesa_receipt_number);

-- 5. Supervisor Void Authorization Audits (Scanned Badge / PIN Security Trail)
CREATE TABLE IF NOT EXISTS supervisor_void_audits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    sale_id UUID REFERENCES sales(id) ON DELETE SET NULL,
    sale_item_id UUID REFERENCES sale_items(id) ON DELETE SET NULL,
    cashier_user_id UUID NOT NULL REFERENCES users(id),
    supervisor_user_id UUID NOT NULL REFERENCES users(id),
    auth_method VARCHAR(50) NOT NULL, -- badge_scan | pin_entry
    void_type VARCHAR(50) NOT NULL, -- single_item | full_transaction | quantity_decrease
    item_name VARCHAR(255),
    item_barcode VARCHAR(100),
    void_quantity NUMERIC(10, 2) DEFAULT 1.00,
    void_amount NUMERIC(12, 2) NOT NULL,
    reason_code VARCHAR(50) NOT NULL, -- wrong_item | customer_changed_mind | damaged | price_mismatch | duplicate_scan | test_sale
    custom_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_supervisor_void_audits_branch ON supervisor_void_audits(branch_id);
CREATE INDEX IF NOT EXISTS idx_supervisor_void_audits_supervisor ON supervisor_void_audits(supervisor_user_id);
CREATE INDEX IF NOT EXISTS idx_supervisor_void_audits_created ON supervisor_void_audits(created_at DESC);

-- Trigger for sales updated_at
CREATE TRIGGER update_sales_updated_at
    BEFORE UPDATE ON sales
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
