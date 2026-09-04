"""Initial schema and Row Level Security policies

Revision ID: 0001_initial_schema
Revises: 
Create Date: 2026-09-03 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = '0001_initial_schema'
down_revision = None
branch_labels = None
depends_on = None

def upgrade() -> None:
    # 1. Enable pgcrypto for UUIDs if not already enabled
    op.execute('CREATE EXTENSION IF NOT EXISTS "pgcrypto";')

    # 2. Create Organizations
    op.create_table(
        'organizations',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('name', sa.Text(), nullable=False),
        sa.Column('business_type', sa.Text(), nullable=False),
        sa.Column('subdomain', sa.Text(), unique=True, nullable=True),
        sa.Column('owner_name', sa.Text(), nullable=False),
        sa.Column('phone_number', sa.Text(), nullable=False),
        sa.Column('plan', sa.Text(), server_default='trial', nullable=False),
        sa.Column('billing_status', sa.Text(), server_default='pending_setup_fee', nullable=False),
        sa.Column('setup_fee_paid', sa.Boolean(), server_default='false', nullable=False),
        sa.Column('license_key', sa.Text(), unique=True, nullable=True),
        sa.Column('trial_ends_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False)
    )

    # 3. Create Branches
    op.create_table(
        'branches',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('organization_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('organizations.id', ondelete='CASCADE'), nullable=False),
        sa.Column('name', sa.Text(), nullable=False),
        sa.Column('location', sa.Text(), nullable=True),
        sa.Column('till_number', sa.Text(), nullable=True),
        sa.Column('is_active', sa.Boolean(), server_default='true', nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False)
    )

    # 4. Create Modules Catalog
    op.create_table(
        'modules',
        sa.Column('key', sa.Text(), primary_key=True),
        sa.Column('display_name', sa.Text(), nullable=False),
        sa.Column('description', sa.Text(), nullable=True)
    )

    # 5. Create Branch Modules
    op.create_table(
        'branch_modules',
        sa.Column('branch_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('branches.id', ondelete='CASCADE'), primary_key=True),
        sa.Column('module_key', sa.Text(), sa.ForeignKey('modules.key', ondelete='CASCADE'), primary_key=True),
        sa.Column('is_enabled', sa.Boolean(), server_default='true', nullable=False),
        sa.Column('config', postgresql.JSONB(astext_type=sa.Text()), server_default='{}', nullable=False)
    )

    # 6. Create Business Type Defaults
    op.create_table(
        'business_type_defaults',
        sa.Column('business_type', sa.Text(), primary_key=True),
        sa.Column('module_key', sa.Text(), sa.ForeignKey('modules.key', ondelete='CASCADE'), primary_key=True)
    )

    # 7. Create Users
    op.create_table(
        'users',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('organization_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('organizations.id', ondelete='CASCADE'), nullable=False),
        sa.Column('branch_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('branches.id', ondelete='SET NULL'), nullable=True),
        sa.Column('email', sa.Text(), nullable=False),
        sa.Column('full_name', sa.Text(), nullable=False),
        sa.Column('password_hash', sa.Text(), nullable=False),
        sa.Column('pin_code', sa.Text(), nullable=True),
        sa.Column('role', sa.Text(), nullable=False),
        sa.Column('is_active', sa.Boolean(), server_default='true', nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint('organization_id', 'email', name='uq_org_email')
    )

    # 8. PostgreSQL Row-Level Security (RLS) Configuration
    # Enable RLS on multi-tenant tables
    tables_with_org_rls = ['branches', 'users']
    for table in tables_with_org_rls:
        op.execute(f"ALTER TABLE {table} ENABLE ROW LEVEL SECURITY;")
        op.execute(f"""
            CREATE POLICY org_isolation_policy ON {table}
            USING (
                organization_id = NULLIF(current_setting('app.current_org_id', true), '')::uuid
                OR current_setting('app.current_org_id', true) IS NULL
            );
        """)

def downgrade() -> None:
    op.drop_table('users')
    op.drop_table('business_type_defaults')
    op.drop_table('branch_modules')
    op.drop_table('modules')
    op.drop_table('branches')
    op.drop_table('organizations')
