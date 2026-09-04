#!/usr/bin/env python3
"""
Hirall POS — Database Migration Runner
Executes ordered SQL migrations against PostgreSQL / Amazon RDS and tracks version history.
"""

import os
import sys
import hashlib
import glob
from pathlib import Path
from dotenv import load_dotenv

# Try importing psycopg or psycopg2
try:
    import psycopg
    PSYCOPG_VERSION = 3
except ImportError:
    try:
        import psycopg2 as psycopg
        PSYCOPG_VERSION = 2
    except ImportError:
        print("❌ Error: psycopg or psycopg2 must be installed to run migrations.")
        print("Run: pip install 'psycopg[binary]'")
        sys.exit(1)

# Find root directory & load env files
DATABASE_DIR = Path(__file__).resolve().parent
ROOT_DIR = DATABASE_DIR.parent
BACKEND_DIR = ROOT_DIR / "backend"

load_dotenv(BACKEND_DIR / ".env")
load_dotenv(ROOT_DIR / ".env")

DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    print("❌ Error: DATABASE_URL not found in environment or .env file.")
    sys.exit(1)

# Clean SQLAlchemy driver prefixes (e.g. postgresql+psycopg:// -> postgresql://)
CLEAN_DB_URL = DATABASE_URL
if "postgresql+psycopg://" in CLEAN_DB_URL:
    CLEAN_DB_URL = CLEAN_DB_URL.replace("postgresql+psycopg://", "postgresql://", 1)
elif "postgresql+asyncpg://" in CLEAN_DB_URL:
    CLEAN_DB_URL = CLEAN_DB_URL.replace("postgresql+asyncpg://", "postgresql://", 1)

def get_connection():
    return psycopg.connect(CLEAN_DB_URL)

def calculate_checksum(file_path: Path) -> str:
    hasher = hashlib.sha256()
    with open(file_path, "rb") as f:
        hasher.update(f.read())
    return hasher.hexdigest()[:16]

def init_migration_table(conn):
    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version VARCHAR(255) PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                checksum VARCHAR(64)
            );
        """)
        conn.commit()

def get_applied_migrations(conn) -> dict:
    with conn.cursor() as cur:
        cur.execute("SELECT version, name, applied_at, checksum FROM schema_migrations ORDER BY version ASC;")
        rows = cur.fetchall()
        return {r[0]: {"name": r[1], "applied_at": r[2], "checksum": r[3]} for r in rows}

def run_migrations():
    print("=" * 70)
    print("🚀 HIRALL POS DATABASE MIGRATION ENGINE")
    print("=" * 70)
    
    host_display = CLEAN_DB_URL.split("@")[-1] if "@" in CLEAN_DB_URL else "localhost"
    print(f"📡 Target Database: {host_display}")
    
    conn = get_connection()
    init_migration_table(conn)
    applied = get_applied_migrations(conn)
    
    migration_files = sorted(glob.glob(str(DATABASE_DIR / "migrations" / "*.sql")))
    
    if not migration_files:
        print("⚠️ No migration files found in database/migrations/")
        return
    
    pending = []
    for mpath in migration_files:
        p = Path(mpath)
        version = p.name.split("_")[0]
        if version not in applied:
            pending.append((version, p.name, p))
            
    print(f"📊 Status: {len(applied)} applied, {len(pending)} pending out of {len(migration_files)} total.")
    print("-" * 70)
    
    if not pending:
        print("✅ Database is up to date! All migrations already applied.")
        return
    
    for version, name, path in pending:
        checksum = calculate_checksum(path)
        print(f"⏳ Applying [{version}] {name}...", end=" ", flush=True)
        
        with open(path, "r", encoding="utf-8") as f:
            sql_content = f.read()
            
        try:
            with conn.cursor() as cur:
                cur.execute(sql_content)
                cur.execute(
                    "INSERT INTO schema_migrations (version, name, checksum) VALUES (%s, %s, %s);",
                    (version, name, checksum)
                )
            conn.commit()
            print("✅ SUCCESS")
        except Exception as e:
            conn.rollback()
            print("❌ FAILED")
            print(f"\nMigration Error in {name}:")
            print(str(e))
            sys.exit(1)
            
    print("-" * 70)
    print(f"🎉 Successfully applied {len(pending)} migrations!")

def show_status():
    conn = get_connection()
    init_migration_table(conn)
    applied = get_applied_migrations(conn)
    migration_files = sorted(glob.glob(str(DATABASE_DIR / "migrations" / "*.sql")))
    
    print("\n📋 HIRALL POS MIGRATION STATUS")
    print("-" * 75)
    print(f"{'Version':<10} {'Migration Name':<45} {'Status':<10} {'Applied At'}")
    print("-" * 75)
    
    for mpath in migration_files:
        p = Path(mpath)
        version = p.name.split("_")[0]
        if version in applied:
            app_info = applied[version]
            date_str = app_info["applied_at"].strftime("%Y-%m-%d %H:%M") if app_info["applied_at"] else "N/A"
            print(f"{version:<10} {p.name:<45} {'✅ Applied':<10} {date_str}")
        else:
            print(f"{version:<10} {p.name:<45} {'⏳ Pending':<10} -")
    print("-" * 75)

if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "up"
    if action == "status":
        show_status()
    else:
        run_migrations()
