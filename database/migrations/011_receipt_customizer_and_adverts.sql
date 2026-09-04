-- =============================================================================
-- HIRALL POS MIGRATION 011: THERMAL RECEIPT CUSTOMIZER, HOLIDAYS & ADVERTS
-- =============================================================================

-- 1. Master Thermal Receipt Configuration Templates
CREATE TABLE IF NOT EXISTS receipt_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id) ON DELETE CASCADE, -- NULL = Org Master Default
    template_name VARCHAR(100) NOT NULL DEFAULT 'Standard Thermal Template',
    is_active BOOLEAN DEFAULT true,
    
    -- Paper & Header Format
    paper_width VARCHAR(20) NOT NULL DEFAULT '80mm', -- 80mm | 58mm
    header_alignment VARCHAR(20) NOT NULL DEFAULT 'center', -- center | left
    logo_asset_id UUID REFERENCES org_assets(id) ON DELETE SET NULL,
    logo_width_px INT NOT NULL DEFAULT 160,
    logo_monochrome BOOLEAN NOT NULL DEFAULT true,
    
    -- Feature Visibility Toggles
    show_logo BOOLEAN NOT NULL DEFAULT true,
    show_address BOOLEAN NOT NULL DEFAULT true,
    show_contact BOOLEAN NOT NULL DEFAULT true,
    show_till_staff BOOLEAN NOT NULL DEFAULT true,
    show_vat_breakdown BOOLEAN NOT NULL DEFAULT true,
    show_mpesa_code BOOLEAN NOT NULL DEFAULT true,
    show_barcode BOOLEAN NOT NULL DEFAULT true,
    show_return_policy BOOLEAN NOT NULL DEFAULT true,
    return_policy_text TEXT DEFAULT 'Goods once sold can be exchanged within 7 days with original receipt. Non-perishables only.',
    thank_you_note TEXT DEFAULT 'Thank you for shopping with us! We appreciate your loyalty.',
    
    -- Double-Sided Duplex Settings (Back of Receipt)
    double_sided_duplex_enabled BOOLEAN NOT NULL DEFAULT true,
    back_terms_and_conditions TEXT DEFAULT '1. Retain receipt for proof of purchase and warranty claims.
2. Electrical appliances carry a 12-month manufacturer warranty.
3. Fresh butchery, dairy & bakery items must be inspected upon purchase.
4. Promotional items and discounted clearance goods are final sale.',
    
    -- Promotional Discount Coupon / Voucher
    show_voucher_coupon BOOLEAN NOT NULL DEFAULT true,
    voucher_title VARCHAR(255) DEFAULT '🎁 GET 10% OFF YOUR NEXT VISIT!',
    voucher_code VARCHAR(100) DEFAULT 'SAVE-10-LOYALTY',
    voucher_details TEXT DEFAULT 'Valid for 30 days on purchases over KES 2,500. Present this receipt.',
    
    -- Customer Satisfaction Survey QR Code
    show_survey_qr BOOLEAN NOT NULL DEFAULT true,
    survey_callout_text VARCHAR(255) DEFAULT 'Rate your cashier & win grocery vouchers!',
    survey_target_url TEXT DEFAULT 'https://feedback.hirallpos.com',
    
    -- Marketing Advert & Sponsor Banner
    show_advert_banner BOOLEAN NOT NULL DEFAULT true,
    advert_title VARCHAR(255) DEFAULT '⚡ ULTRA-FAST 5G HOME FIBRE AVAILABLE IN-STORE!',
    advert_body TEXT DEFAULT 'Sign up at Customer Service today. Free router installation.',
    advert_social_handles VARCHAR(255) DEFAULT 'Follow our social channels for weekly flash deals',
    
    -- Festive & Seasonal Greetings Engine
    festive_greetings_enabled BOOLEAN NOT NULL DEFAULT true,
    festive_preset VARCHAR(50) DEFAULT 'christmas', -- christmas | eid | jamhuri | blackfriday | easter | custom
    festive_header_banner TEXT DEFAULT '🎄 MERRY CHRISTMAS & HAPPY NEW YEAR 2026! 🎁',
    festive_footer_message TEXT DEFAULT 'Wishing you and your family joy, peace, and abundance this holiday season!',
    festive_border_style VARCHAR(50) DEFAULT 'icons', -- icons | stars | snowflakes | dashes
    festive_placement VARCHAR(50) DEFAULT 'both', -- top | bottom | both
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_receipt_templates_org ON receipt_templates(organization_id);
CREATE INDEX IF NOT EXISTS idx_receipt_templates_branch ON receipt_templates(branch_id);

-- Trigger for updated_at
CREATE TRIGGER update_receipt_templates_updated_at
    BEFORE UPDATE ON receipt_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
