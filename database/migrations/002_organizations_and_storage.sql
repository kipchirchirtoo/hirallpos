-- =============================================================================
-- HIRALL POS MIGRATION 002: MULTI-TENANT ORGANIZATIONS & SECURE STORAGE
-- =============================================================================

-- 1. Organizations Master Table (Multi-Tenant Root)
CREATE TABLE IF NOT EXISTS organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    trading_name VARCHAR(255),
    subdomain VARCHAR(100) UNIQUE NOT NULL,
    business_type VARCHAR(50) NOT NULL DEFAULT 'supermarket',
    owner_name VARCHAR(255),
    phone_number VARCHAR(50),
    email VARCHAR(255),
    tax_pin VARCHAR(50),
    plan VARCHAR(50) DEFAULT 'trial',
    billing_status VARCHAR(50) DEFAULT 'active',
    license_key VARCHAR(100) UNIQUE,
    trial_ends_at TIMESTAMP WITH TIME ZONE,
    logo_url TEXT,
    currency VARCHAR(10) DEFAULT 'KES',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_organizations_subdomain ON organizations(subdomain);
CREATE INDEX IF NOT EXISTS idx_organizations_license_key ON organizations(license_key);

-- 2. Organization Secure Storage Buckets
CREATE TABLE IF NOT EXISTS org_storage_buckets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    bucket_name VARCHAR(100) NOT NULL,
    bucket_type VARCHAR(50) NOT NULL DEFAULT 'logos', -- logos | receipts | marketing | documents
    is_public BOOLEAN DEFAULT false,
    max_file_size_bytes BIGINT DEFAULT 5242880, -- 5 MB default limit
    allowed_mime_types TEXT[] DEFAULT ARRAY['image/png', 'image/jpeg', 'image/svg+xml', 'image/webp'],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_org_bucket UNIQUE (organization_id, bucket_name)
);

CREATE INDEX IF NOT EXISTS idx_org_storage_buckets_org ON org_storage_buckets(organization_id);

-- 3. Organization Uploaded Assets (Logos, Receipt Banners, Adverts)
CREATE TABLE IF NOT EXISTS org_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    bucket_id UUID REFERENCES org_storage_buckets(id) ON DELETE SET NULL,
    asset_type VARCHAR(50) NOT NULL DEFAULT 'logo', -- logo | receipt_banner | promo_voucher | advert | staff_avatar
    file_name VARCHAR(255) NOT NULL,
    file_size_bytes BIGINT NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    storage_path TEXT NOT NULL,
    public_url TEXT NOT NULL,
    width INT,
    height INT,
    metadata JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN DEFAULT true,
    uploaded_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_org_assets_org ON org_assets(organization_id);
CREATE INDEX IF NOT EXISTS idx_org_assets_type ON org_assets(organization_id, asset_type);

-- Triggers for updated_at
CREATE TRIGGER update_organizations_updated_at
    BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_org_storage_buckets_updated_at
    BEFORE UPDATE ON org_storage_buckets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_org_assets_updated_at
    BEFORE UPDATE ON org_assets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
