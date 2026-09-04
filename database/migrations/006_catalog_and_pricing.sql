-- =============================================================================
-- HIRALL POS MIGRATION 006: MASTER PRODUCT CATALOG & PRICING
-- =============================================================================

-- 1. Tax Rates Table (e.g. Kenya 16% VAT, 0% Zero-Rated, Exempt)
CREATE TABLE IF NOT EXISTS tax_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL, -- e.g. Standard VAT (16%), Zero-Rated (0%), Exempt
    rate_percent NUMERIC(5, 2) NOT NULL DEFAULT 16.00,
    is_inclusive BOOLEAN DEFAULT true, -- Kenya VAT is inclusive on POS receipts
    is_default BOOLEAN DEFAULT false,
    kra_tax_code VARCHAR(10) DEFAULT 'A', -- KRA eTIMS Tax classification A (16%), B (0%), C (Exempt)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tax_rates_org ON tax_rates(organization_id);

-- 2. Master Product Categories
CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255),
    color VARCHAR(20) DEFAULT '#059669',
    icon_name VARCHAR(50) DEFAULT 'shopping-bag',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_org_category_name UNIQUE (organization_id, name)
);

CREATE INDEX IF NOT EXISTS idx_categories_org ON categories(organization_id);

-- 3. Master Products Catalog
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    tax_rate_id UUID REFERENCES tax_rates(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    sku VARCHAR(100),
    barcode VARCHAR(100), -- Primary Barcode EAN-13
    description TEXT,
    cost_price NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    selling_price NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    tax_rate_percent NUMERIC(5, 2) NOT NULL DEFAULT 16.00,
    unit_of_measure VARCHAR(50) NOT NULL DEFAULT 'PCS', -- PCS | KG | LTR | PACK | CRATE | BOTTLE
    is_perishable BOOLEAN DEFAULT false,
    expiry_warning_days INT DEFAULT 7,
    min_stock_alert_threshold NUMERIC(10, 2) DEFAULT 5.00,
    image_asset_id UUID REFERENCES org_assets(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_org_product_sku UNIQUE (organization_id, sku)
);

ALTER TABLE products ADD COLUMN IF NOT EXISTS barcode VARCHAR(100);
ALTER TABLE products ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS tax_rate_id UUID REFERENCES tax_rates(id) ON DELETE SET NULL;
ALTER TABLE products ADD COLUMN IF NOT EXISTS tax_rate_percent NUMERIC(5, 2) DEFAULT 16.00;
ALTER TABLE products ADD COLUMN IF NOT EXISTS unit_of_measure VARCHAR(50) DEFAULT 'PCS';
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_perishable BOOLEAN DEFAULT false;
ALTER TABLE products ADD COLUMN IF NOT EXISTS expiry_warning_days INT DEFAULT 7;
ALTER TABLE products ADD COLUMN IF NOT EXISTS min_stock_alert_threshold NUMERIC(10, 2) DEFAULT 5.00;
ALTER TABLE products ADD COLUMN IF NOT EXISTS image_asset_id UUID REFERENCES org_assets(id) ON DELETE SET NULL;
ALTER TABLE products ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_products_org ON products(organization_id);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(organization_id, barcode);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_name ON products(organization_id, name);

-- 4. Product Secondary Barcode Aliases (Bulk packs, multipacks, crates)
CREATE TABLE IF NOT EXISTS product_barcode_aliases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    barcode VARCHAR(100) NOT NULL,
    pack_quantity NUMERIC(10, 2) NOT NULL DEFAULT 1.00, -- e.g. 1 crate = 24 bottles
    pack_name VARCHAR(100), -- e.g. "Pack of 6", "Outer Crate (24x)"
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_org_barcode_alias UNIQUE (organization_id, barcode)
);

CREATE INDEX IF NOT EXISTS idx_product_barcode_aliases_barcode ON product_barcode_aliases(barcode);

-- 5. Product Pricing Tiers (Wholesale, Happy Hour, VIP, Member)
CREATE TABLE IF NOT EXISTS product_pricing_tiers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    tier_name VARCHAR(100) NOT NULL, -- Retail | Wholesale | Happy Hour | VIP
    min_quantity NUMERIC(10, 2) NOT NULL DEFAULT 1.00,
    tier_price NUMERIC(12, 2) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_product_tier UNIQUE (product_id, tier_name, min_quantity)
);

CREATE INDEX IF NOT EXISTS idx_product_pricing_tiers_product ON product_pricing_tiers(product_id);

-- Triggers for updated_at
CREATE TRIGGER update_categories_updated_at
    BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
