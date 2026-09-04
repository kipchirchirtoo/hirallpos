-- =============================================================================
-- HIRALL POS MIGRATION 010: HOSPITALITY, WAITER & KITCHEN TICKETS (KOT)
-- =============================================================================

-- 1. Restaurant Dining Tables Table
CREATE TABLE IF NOT EXISTS restaurant_tables (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    table_number VARCHAR(50) NOT NULL, -- e.g. T-01, TERRACE-4, VIP-L02
    section_name VARCHAR(100) DEFAULT 'Main Dining Area',
    capacity INT NOT NULL DEFAULT 4,
    status VARCHAR(50) NOT NULL DEFAULT 'available', -- available | occupied | reserved | billing | dirty
    current_waiter_id UUID REFERENCES users(id) ON DELETE SET NULL,
    current_order_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_branch_table_number UNIQUE (branch_id, table_number)
);

ALTER TABLE restaurant_tables ADD COLUMN IF NOT EXISTS section_name VARCHAR(100) DEFAULT 'Main Dining';
ALTER TABLE restaurant_tables ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'available';
ALTER TABLE restaurant_tables ADD COLUMN IF NOT EXISTS current_waiter_id UUID REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE restaurant_tables ADD COLUMN IF NOT EXISTS current_order_id UUID;

CREATE INDEX IF NOT EXISTS idx_tables_branch ON restaurant_tables(branch_id);
CREATE INDEX IF NOT EXISTS idx_tables_status ON restaurant_tables(branch_id, status);

-- 2. Table Active Dining Sessions
CREATE TABLE IF NOT EXISTS table_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    table_id UUID NOT NULL REFERENCES restaurant_tables(id) ON DELETE CASCADE,
    waiter_user_id UUID NOT NULL REFERENCES users(id),
    guest_count INT NOT NULL DEFAULT 2,
    opened_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(50) NOT NULL DEFAULT 'active', -- active | billed | closed
    total_bill_amount NUMERIC(12, 2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_table_sessions_table ON table_sessions(table_id);

-- 3. Kitchen Order Tickets (KOT) & Bar Order Tickets (BOT)
CREATE TABLE IF NOT EXISTS kitchen_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    table_id UUID NOT NULL REFERENCES restaurant_tables(id) ON DELETE CASCADE,
    session_id UUID REFERENCES table_sessions(id) ON DELETE SET NULL,
    kot_number VARCHAR(100) NOT NULL,
    waiter_user_id UUID NOT NULL REFERENCES users(id),
    preparation_station VARCHAR(50) DEFAULT 'kitchen', -- kitchen | bar | grill | bakery
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending | preparing | ready | served | cancelled
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE kitchen_orders ADD COLUMN IF NOT EXISTS kot_number VARCHAR(100);
ALTER TABLE kitchen_orders ADD COLUMN IF NOT EXISTS preparation_station VARCHAR(50) DEFAULT 'kitchen';
ALTER TABLE kitchen_orders ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'pending';
ALTER TABLE kitchen_orders ADD COLUMN IF NOT EXISTS session_id UUID REFERENCES table_sessions(id) ON DELETE SET NULL;
ALTER TABLE kitchen_orders ADD COLUMN IF NOT EXISTS notes TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS uq_org_kot_number ON kitchen_orders(organization_id, kot_number);
CREATE INDEX IF NOT EXISTS idx_kitchen_orders_branch ON kitchen_orders(branch_id);
CREATE INDEX IF NOT EXISTS idx_kitchen_orders_status ON kitchen_orders(branch_id, status);

-- 4. KOT Itemized Dishes & Custom Modifiers
CREATE TABLE IF NOT EXISTS kitchen_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kot_id UUID NOT NULL REFERENCES kitchen_orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity NUMERIC(10, 2) NOT NULL DEFAULT 1.00,
    special_instructions TEXT, -- e.g. "No onions, extra chili, medium rare"
    item_status VARCHAR(50) DEFAULT 'queued', -- queued | cooking | served | voided
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_kitchen_order_items_kot ON kitchen_order_items(kot_id);

-- Trigger for restaurant_tables updated_at
CREATE TRIGGER update_restaurant_tables_updated_at
    BEFORE UPDATE ON restaurant_tables
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
