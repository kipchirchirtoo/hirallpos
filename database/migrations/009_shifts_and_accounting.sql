-- =============================================================================
-- HIRALL POS MIGRATION 009: CASHIER SHIFTS, EXPENSES & RECONCILIATION
-- =============================================================================

-- 1. Cashier Till Shifts Table (Float Opening & Shift Z-Report Closing)
CREATE TABLE IF NOT EXISTS cashier_shifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    till_id UUID NOT NULL REFERENCES till_registers(id) ON DELETE CASCADE,
    cashier_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    opened_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMP WITH TIME ZONE,
    opening_float NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    expected_cash NUMERIC(12, 2) DEFAULT 0.00,
    counted_cash NUMERIC(12, 2) DEFAULT 0.00,
    cash_difference NUMERIC(12, 2) DEFAULT 0.00, -- negative = shortage, positive = surplus
    total_sales_gross NUMERIC(12, 2) DEFAULT 0.00,
    total_mpesa_sales NUMERIC(12, 2) DEFAULT 0.00,
    total_card_sales NUMERIC(12, 2) DEFAULT 0.00,
    total_expenses_paid NUMERIC(12, 2) DEFAULT 0.00,
    status VARCHAR(50) NOT NULL DEFAULT 'open', -- open | closed | reconciled
    closing_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_shifts_branch ON cashier_shifts(branch_id);
CREATE INDEX IF NOT EXISTS idx_shifts_cashier ON cashier_shifts(cashier_id);
CREATE INDEX IF NOT EXISTS idx_shifts_status ON cashier_shifts(branch_id, status);

-- 2. Daily Till Reconciliations (End of Day Audit)
CREATE TABLE IF NOT EXISTS till_reconciliations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    till_id UUID NOT NULL REFERENCES till_registers(id) ON DELETE CASCADE,
    shift_id UUID REFERENCES cashier_shifts(id) ON DELETE SET NULL,
    reconciliation_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expected_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    counted_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    variance NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    status VARCHAR(50) NOT NULL DEFAULT 'balanced', -- balanced | shortage | overage
    audited_by_user_id UUID REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE till_reconciliations ADD COLUMN IF NOT EXISTS shift_id UUID REFERENCES cashier_shifts(id) ON DELETE SET NULL;
ALTER TABLE till_reconciliations ADD COLUMN IF NOT EXISTS reconciliation_date DATE DEFAULT CURRENT_DATE;
ALTER TABLE till_reconciliations ADD COLUMN IF NOT EXISTS expected_amount NUMERIC(12, 2) DEFAULT 0.00;
ALTER TABLE till_reconciliations ADD COLUMN IF NOT EXISTS counted_amount NUMERIC(12, 2) DEFAULT 0.00;
ALTER TABLE till_reconciliations ADD COLUMN IF NOT EXISTS variance NUMERIC(12, 2) DEFAULT 0.00;
ALTER TABLE till_reconciliations ADD COLUMN IF NOT EXISTS audited_by_user_id UUID REFERENCES users(id);

CREATE INDEX IF NOT EXISTS idx_reconciliations_branch ON till_reconciliations(branch_id);

-- 3. Branch Operating Expenses (Petty Cash & Overhead)
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    shift_id UUID REFERENCES cashier_shifts(id) ON DELETE SET NULL,
    category VARCHAR(100) NOT NULL, -- petty_cash | utilities | logistics | repairs | supplies
    description TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL DEFAULT 'cash', -- cash | mpesa | bank_transfer
    logged_by_user_id UUID REFERENCES users(id),
    approved_by_user_id UUID REFERENCES users(id),
    receipt_asset_id UUID REFERENCES org_assets(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE expenses ADD COLUMN IF NOT EXISTS shift_id UUID REFERENCES cashier_shifts(id) ON DELETE SET NULL;
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS logged_by_user_id UUID REFERENCES users(id);
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS approved_by_user_id UUID REFERENCES users(id);
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS receipt_asset_id UUID REFERENCES org_assets(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_expenses_branch ON expenses(branch_id);
CREATE INDEX IF NOT EXISTS idx_expenses_created ON expenses(branch_id, created_at DESC);

-- 4. Daily Branch Profit & Loss Summaries
CREATE TABLE IF NOT EXISTS daily_pl_summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    summary_date DATE NOT NULL,
    gross_revenue NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    cost_of_goods_sold NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    gross_profit NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_operating_expenses NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    net_profit NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_orders_count INT NOT NULL DEFAULT 0,
    total_vat_collected NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_branch_daily_pl UNIQUE (branch_id, summary_date)
);

CREATE INDEX IF NOT EXISTS idx_daily_pl_branch ON daily_pl_summaries(branch_id, summary_date DESC);
