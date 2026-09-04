-- =============================================================================
-- HIRALL POS MIGRATION 007: MULTI-BRANCH INVENTORY & STOCK TRANSFERS
-- =============================================================================

-- 1. Branch Inventory Levels (Stock per Branch)
CREATE TABLE IF NOT EXISTS branch_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    current_stock NUMERIC(12, 3) NOT NULL DEFAULT 0.000,
    reorder_level NUMERIC(12, 3) NOT NULL DEFAULT 5.000,
    ideal_stock_level NUMERIC(12, 3) DEFAULT 50.000,
    last_stock_take_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_branch_product_inventory ON branch_inventory(branch_id, product_id);
CREATE INDEX IF NOT EXISTS idx_branch_inventory_branch ON branch_inventory(branch_id);
CREATE INDEX IF NOT EXISTS idx_branch_inventory_product ON branch_inventory(product_id);
CREATE INDEX IF NOT EXISTS idx_branch_inventory_low_stock ON branch_inventory(branch_id) WHERE current_stock <= reorder_level;

-- 2. Goods Received Notes (GRN - Supplier Stock Deliveries)
CREATE TABLE IF NOT EXISTS goods_received_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    grn_number VARCHAR(100) NOT NULL,
    supplier_name VARCHAR(255) NOT NULL,
    supplier_invoice_number VARCHAR(100),
    total_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    status VARCHAR(50) DEFAULT 'completed', -- draft | completed | cancelled
    received_by_user_id UUID REFERENCES users(id),
    received_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_org_grn_number ON goods_received_notes(organization_id, grn_number);
CREATE INDEX IF NOT EXISTS idx_grn_branch ON goods_received_notes(branch_id);
CREATE INDEX IF NOT EXISTS idx_grn_org ON goods_received_notes(organization_id);

-- 3. GRN Line Items
CREATE TABLE IF NOT EXISTS grn_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    grn_id UUID NOT NULL REFERENCES goods_received_notes(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity_received NUMERIC(12, 3) NOT NULL,
    unit_cost_price NUMERIC(12, 2) NOT NULL,
    batch_number VARCHAR(100),
    expiry_date DATE,
    line_total NUMERIC(12, 2) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_grn_items_grn ON grn_items(grn_id);

-- 4. Inter-Branch Stock Transfers
CREATE TABLE IF NOT EXISTS stock_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    transfer_number VARCHAR(100) NOT NULL,
    source_branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    destination_branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    status VARCHAR(50) NOT NULL DEFAULT 'draft', -- draft | in_transit | received | cancelled | rejected
    total_cost NUMERIC(12, 2) DEFAULT 0.00,
    initiated_by_user_id UUID REFERENCES users(id),
    received_by_user_id UUID REFERENCES users(id),
    dispatched_at TIMESTAMP WITH TIME ZONE,
    received_at TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE stock_transfers ADD COLUMN IF NOT EXISTS transfer_number VARCHAR(100);
ALTER TABLE stock_transfers ADD COLUMN IF NOT EXISTS total_cost NUMERIC(12, 2) DEFAULT 0.00;
ALTER TABLE stock_transfers ADD COLUMN IF NOT EXISTS initiated_by_user_id UUID REFERENCES users(id);
ALTER TABLE stock_transfers ADD COLUMN IF NOT EXISTS received_by_user_id UUID REFERENCES users(id);
ALTER TABLE stock_transfers ADD COLUMN IF NOT EXISTS dispatched_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE stock_transfers ADD COLUMN IF NOT EXISTS received_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE stock_transfers ADD COLUMN IF NOT EXISTS notes TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS uq_org_transfer_number ON stock_transfers(organization_id, transfer_number);

CREATE INDEX IF NOT EXISTS idx_stock_transfers_source ON stock_transfers(source_branch_id);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_dest ON stock_transfers(destination_branch_id);

-- 5. Stock Transfer Line Items
CREATE TABLE IF NOT EXISTS stock_transfer_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transfer_id UUID NOT NULL REFERENCES stock_transfers(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity_dispatched NUMERIC(12, 3) NOT NULL,
    quantity_received NUMERIC(12, 3) DEFAULT 0.000,
    unit_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00
);

CREATE INDEX IF NOT EXISTS idx_stock_transfer_items_transfer ON stock_transfer_items(transfer_id);

-- 6. Stock Adjustments (Shrinkage, Spoilage, Damage, Audit variance)
CREATE TABLE IF NOT EXISTS stock_adjustments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    adjustment_type VARCHAR(50) NOT NULL, -- breakage | spoilage | theft_shrinkage | audit_reconciliation | return_to_supplier
    quantity_delta NUMERIC(12, 3) NOT NULL, -- negative for loss, positive for found
    cost_impact NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    authorized_by_user_id UUID REFERENCES users(id),
    reason TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_stock_adjustments_branch ON stock_adjustments(branch_id);

-- Trigger for branch_inventory updated_at
CREATE TRIGGER update_branch_inventory_updated_at
    BEFORE UPDATE ON branch_inventory
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
