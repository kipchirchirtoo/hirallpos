-- ====================================================================
-- Hirall POS: PostgreSQL Logical Replication Setup for PowerSync
-- ====================================================================

-- 1. Ensure WAL level is logical (requires postgres restart if changed on standalone)
-- ALTER SYSTEM SET wal_level = 'logical';

-- 2. Create PowerSync User (if running dedicated sync user)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'powersync_role') THEN
        CREATE ROLE powersync_role WITH LOGIN PASSWORD 'powersync_secure_password' REPLICATION;
    END IF;
END
$$;

-- 3. Grant schema permissions
GRANT USAGE ON SCHEMA public TO powersync_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO powersync_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO powersync_role;

-- 4. Create Publication for PowerSync replication
DROP PUBLICATION IF EXISTS powersync_publication;
CREATE PUBLICATION powersync_publication FOR ALL TABLES;

-- 5. PowerSync Logical Replication Slot
-- SELECT pg_create_logical_replication_slot('powersync_slot', 'pgoutput');
