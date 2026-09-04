# PowerSync Configuration for Hirall POS

Hirall POS utilizes **PowerSync** as its offline-first data synchronization engine between the central PostgreSQL (AWS RDS) database and the Flutter Desktop client (SQLite/Drift).

## Architecture

1. **PostgreSQL (System of Record)**: Runs on AWS RDS with `wal_level = logical`.
2. **Replication Slot (`pgoutput`)**: PowerSync service connects to PostgreSQL logical replication slot `powersync_slot` and streams CDC (Change Data Capture) events.
3. **Partitioning (`sync_rules.yaml`)**:
   - `org_data`: Global organization metadata, products catalog, categories, modules, branches.
   - `branch_data`: Real-time operational data scoped to `branch_id` (sales, stock levels, orders, shifts, reconciliations).
   - `user_data`: Staff records and roles for the organization.
4. **Client-Side (Flutter Desktop)**: SQLite database queried via Drift ORM with Riverpod state management. Writes queue locally while offline and auto-upload when back online.

## Deployment & Setup

### Cloud PowerSync Service (Managed)
1. Go to PowerSync Dashboard > Create Project.
2. Enter your RDS PostgreSQL connection details.
3. Upload `sync_rules.yaml`.
4. Configure the JWT public key matching FastAPI's `POWERSYNC_PUBLIC_KEY`.

### Self-Hosted PowerSync Service (Open Edition)
Run the PowerSync Service Docker container pointing to PostgreSQL:
```bash
docker run -p 8080:8080 \
  -e POWERSYNC_PORT=8080 \
  -e POWERSYNC_DATABASE_URI=postgres://postgres:postgres@postgres:5432/hirall_pos \
  journeyapps/powersync-service:latest
```
