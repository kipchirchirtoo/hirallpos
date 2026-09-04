-- =============================================================================
-- HIRALL POS MIGRATION 003: MULTI-BRANCH HIERARCHY & TILL REGISTERS
-- =============================================================================

-- 1. Branches Table (HQ & Retail Outlets)
CREATE TABLE IF NOT EXISTS branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    short_code VARCHAR(50) NOT NULL DEFAULT 'MAIN',
    is_hq BOOLEAN DEFAULT false,
    building VARCHAR(255),
    street VARCHAR(255),
    city VARCHAR(100) DEFAULT 'Nairobi',
    postal_address VARCHAR(100),
    phone_number VARCHAR(50),
    email VARCHAR(255),
    mpesa_paybill VARCHAR(50),
    mpesa_account_reference VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    settings JSONB DEFAULT '{
        "require_supervisor_void": true,
        "allow_negative_stock": false,
        "max_cash_drawer_limit": 50000.0,
        "receipt_paper_width": "80mm"
    }'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_org_branch_code UNIQUE (organization_id, short_code)
);

CREATE INDEX IF NOT EXISTS idx_branches_org ON branches(organization_id);

-- 2. Till Registers (Checkout Lanes per Branch)
CREATE TABLE IF NOT EXISTS till_registers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    till_number VARCHAR(50) NOT NULL, -- e.g. TILL-01, LANE-02, EXPRESS-01
    display_name VARCHAR(100) NOT NULL,
    device_fingerprint VARCHAR(255),
    ip_address VARCHAR(45),
    is_online BOOLEAN DEFAULT false,
    last_sync_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(50) DEFAULT 'active', -- active | suspended | maintenance
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_branch_till_number UNIQUE (branch_id, till_number)
);

CREATE INDEX IF NOT EXISTS idx_till_registers_branch ON till_registers(branch_id);
CREATE INDEX IF NOT EXISTS idx_till_registers_org ON till_registers(organization_id);

-- Triggers for updated_at
CREATE TRIGGER update_branches_updated_at
    BEFORE UPDATE ON branches
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_till_registers_updated_at
    BEFORE UPDATE ON till_registers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
