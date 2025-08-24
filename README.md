# Simple Schema Versions

This project provides simple rules and utilities for managing schema changes in a PostgreSQL database. It helps track and manage schema versions, making migrations and upgrades easier and safer.

It uses pure SQL functions and does not rely on any external functionality.

## Features

- **Schema Type Identification:**  
  Use the `get_schema_type()` function to identify the type of schema in multi-schema environments.

- **Schema Version Tracking:**  
  The `db_schema_version` table stores the history of schema versions applied to the database.

- **Version Management Functions:**  
  - `get_schema_version()`: Returns the current schema version in `major.minor.patch` format.
  - `set_schema_version(major, minor, patch)`: Updates the schema version after migrations.

## Setup

1. **Initialize the schema versioning system:**  
   Run the SQL statements in [`001_add_schema_versioning.sql`](sql/migrate/0.1/001_add_schema_versioning.sql) to set up the required functions and tables.

2. **Check the current schema version:**  
   ```sql
   SELECT get_schema_version() AS version;
   ```

## Usage

Changes to schemas are built up as a sequence of changes that can be applied, and an optional set of rollback scripts.

The changes should be decoupled from the code changes - so that old code can run with the the new schema changes, and 
then updated code can be rolled out, before cleaning up unused columns.

The [`initdb.sql`](sql/initdb.sql) should be kept up to date as a current snapshot of the full DB for easy loading in new environments.
The *migrate* folder should be a complete record of changes.

The initdb.sql file can easily be updated with the following script (run from the sql directory)
```bash
find migrate -name "*.sql" -type f | sort -V | while read file; do echo "-- source: $file";  cat "$file"; echo "\n"; done > initdb.sql
```

Each of the sql scripts in the migrate folder can be run manually or it can be scripted to run them in a sequence.


## FAQs
### Can I add this to an existing project?
Yes - add in the functions and pick a version number that makes sense.  It's a good idea to do a pgdump of the schema 
and set that as the initial file.  Then simply iterate version numbers.

### Should this match the version number for my application?
In general No - as the DB and the application tend to evolve at different speeds and trying to match the version
tends to make more useless busywork.

### Do I need a rollback file for every change?
If you are using this in a major production application then you really should.  If you are working on a smaller
or early stage project then it can be beneficial to skip them for flexibility.


## Schema evolution best practice and rules.

This section gives concrete, actionable guidelines for evolving schemas while maintaining backward compatibility and minimizing risk.

### Principles
- Prefer additive, backward-compatible changes whenever possible.
- Stage breaking changes: introduce new artifacts, shift traffic, then remove old ones.
- Keep migrations small, reversible, and well-tested.
- Record applied migrations in `db_schema_version` and keep the migration scripts in source control.

### Backward compatibility rules
- Add columns or tables instead of modifying/removing existing ones.
- New columns should be nullable or have safe server-side defaults. Convert to NOT NULL only after backfill and validation.
- Don't change column names or types in-place. Use dual-write/shadow columns and cutover later.
- Keep stable function and view signatures; change implementation behind the stable API.

### Safe-change patterns

- Adding a column (recommended flow)
  1. Add the column nullable with no heavy default.
  2. Deploy application code that writes/reads the new column defensively.
  3. Backfill values in a controlled batch job.
  4. Validate backfill and then add NOT NULL / default in a separate migration.

  Example (Postgres):
  ```sql
  ALTER TABLE users ADD COLUMN bio TEXT;
  -- backfill as a separate job
  UPDATE users SET bio = '' WHERE bio IS NULL;
  ALTER TABLE users ALTER COLUMN bio SET NOT NULL;
  ```

- Renaming a column (safe approach)
  1. Add the new column.
  2. Update application to write to both old and new columns.
  3. Backfill new column from old.
  4. Switch reads to the new column.
  5. Drop old column only after all clients use the new one.

- Changing a type
  1. Add a new column with target type.
  2. Backfill using safe casts in batches.
  3. Update app to read/write new column.
  4. Remove old column once cutover is complete.

- Constraints and indexes
  - Create large indexes CONCURRENTLY (Postgres) to avoid blocking writes.
  - Add constraints using NOT VALID, backfill, then VALIDATE:
    ```sql
    ALTER TABLE orders ADD CONSTRAINT chk_amount_positive CHECK (amount > 0) NOT VALID;
    -- backfill/fix rows
    ALTER TABLE orders VALIDATE CONSTRAINT chk_amount_positive;
    ```

### Migrations & rollbacks
- Write idempotent migrations that can be re-run safely.
- Provide explicit rollback scripts; test both up and down paths in staging.
- Break complex changes into multiple migrations (add, backfill, validate, cleanup).

### Deployment and rollout
- Follow a three-phase deployment: migrate (add artifacts) -> deploy compatible app -> cleanup (remove old artifacts).
- Use feature flags to control behavior during rollout.
- Run long-running migrations at low-traffic times or on replicas when feasible.
- For distributed systems, ensure all services tolerate mixed schemas during transition.

### Testing and observability
- Test migrations locally and in staging with representative data sizes.
- Canary changes on a small subset of instances or replicas.
- Monitor migration duration, locks, errors, and application error rates.
- Log every migration step and the db_schema_version changes.

### Checklist for each schema change
- [ ] Is the change additive or staged for compatibility?
- [ ] Will applications tolerate both old and new schema shapes?
- [ ] Is there a backfill plan and validation step?
- [ ] Are migrations idempotent and reversible?
- [ ] Have migrations been tested on staging with representative data?
- [ ] Is monitoring and alerting configured for the migration?

Keep migration scripts in the repository, include rationale and rollback plans in the commit message, and use `db_schema_version` to track progress. These practices reduce risk and enable predictable, low-downtime schema evolution.
