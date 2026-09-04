-- =============================================================================
-- HIRALL POS MIGRATION 005: MODULAR POS ARCHITECTURE & BRANCH ENTITLEMENTS
-- =============================================================================

-- 1. Master Operational Modules Catalog
CREATE TABLE IF NOT EXISTS modules (
    key VARCHAR(50) PRIMARY KEY,
    display_name VARCHAR(100) NOT NULL,
    description TEXT,
    icon_name VARCHAR(50) DEFAULT 'package',
    category VARCHAR(50) DEFAULT 'core', -- core | retail | hospitality | finance
    is_beta BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE modules ADD COLUMN IF NOT EXISTS icon_name VARCHAR(50) DEFAULT 'package';
ALTER TABLE modules ADD COLUMN IF NOT EXISTS category VARCHAR(50) DEFAULT 'core';
ALTER TABLE modules ADD COLUMN IF NOT EXISTS is_beta BOOLEAN DEFAULT false;

-- 2. Business Type Default Module Matrix
CREATE TABLE IF NOT EXISTS business_type_defaults (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_type VARCHAR(50) NOT NULL, -- supermarket | retail | restaurant | bar_club | laundry | spa
    module_key VARCHAR(50) NOT NULL REFERENCES modules(key) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_btype_module UNIQUE (business_type, module_key)
);

CREATE INDEX IF NOT EXISTS idx_business_type_defaults_type ON business_type_defaults(business_type);

-- 3. Branch Module Entitlements & Runtime Configuration
CREATE TABLE IF NOT EXISTS branch_modules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    module_key VARCHAR(50) NOT NULL REFERENCES modules(key) ON DELETE CASCADE,
    is_enabled BOOLEAN DEFAULT true,
    config JSONB DEFAULT '{}'::jsonb,
    enabled_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_branch_module UNIQUE (branch_id, module_key)
);

ALTER TABLE branch_modules ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_branch_modules_branch ON branch_modules(branch_id);
CREATE INDEX IF NOT EXISTS idx_branch_modules_org ON branch_modules(organization_id);

-- Trigger for updated_at
CREATE TRIGGER update_branch_modules_updated_at
    BEFORE UPDATE ON branch_modules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
