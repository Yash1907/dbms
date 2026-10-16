# KOHA-Lite database project

KOHA-Lite is a MySQL 8 database for recorded circulation across participating Little Free Libraries. It tracks individual physical copies, registered patrons, cross-library returns, donations, explicit visits, director assignments, inventory reconciliation, and immutable audit evidence.

## Deliverables

- `docs/FRD.md` and `output/pdf/KOHA-Lite_FRD.pdf`: functional requirements
- `docs/TDD.md` and `output/pdf/KOHA-Lite_TDD.pdf`: technical design
- `docs/KOHA-Lite_ERD.drawio`: editable draw.io entity-relationship model
- `docs/KOHA-Lite_ERD.mmd` and `output/pdf/KOHA-Lite_ERD.pdf`: reviewable ERD source and PDF
- `database/`: ordered schema, programmability, security, seed, and validation scripts
- `build/build_database.ps1`: exact-tag Windows build script
- `build/koha_lite_workbench_build.sql`: single-file local Workbench build and validation

The live demonstration is intentionally not included.

## Required platform and tools

- MySQL Server 8.0 or later with InnoDB and `utf8mb4_0900_ai_ci`
- MySQL command-line client available as `mysql`
- Git available as `git`
- PowerShell 7 or Windows PowerShell 5.1
- A MySQL administrative account permitted to create a database, routines, triggers, roles, and grants

The reproducible database name is `koha_lite` because the least-privilege grant script names that schema explicitly.

## Release preparation

Commit all project artifacts, then create and push an immutable release tag. Example:

```powershell
git tag -a v1.0.0 -m "KOHA-Lite database deliverable"
git push origin v1.0.0
```

Do not build a submitted release from a changing branch such as `main`.

## Configuration

Set credentials in environment variables. Do not commit credentials.

```powershell
$env:DB_HOST = "127.0.0.1"
$env:DB_PORT = "3306"
$env:DB_ADMIN_USER = "root"
$env:DB_ADMIN_PASSWORD = "replace-with-local-secret"
```

For a private repository, also set `GITHUB_TOKEN`. To intentionally replace an existing classroom database, set `ALLOW_DATABASE_RECREATE=YES`; otherwise the build stops safely.

## Exact-tag build

From a separate working directory, run:

```powershell
.\build_database.ps1 -Owner "OWNER" -Repository "REPOSITORY" -VersionTag "v1.0.0" -TargetDatabase "koha_lite"
```

The script verifies prerequisites and connectivity, clones the exact requested tag, validates `database/manifest.txt`, refuses to overwrite an existing database without explicit opt-in, executes scripts in manifest order, stops on failure, and writes timestamped build/error logs beneath `.build-work/`.

## Manual local build

For development before a release tag exists, open `build/koha_lite_workbench_build.sql` in MySQL Workbench and execute the entire file while connected as a sufficiently privileged account. It creates a fresh `koha_lite` database, runs every manifest file in order, loads sample data, and executes validation. It intentionally fails rather than replacing an existing `koha_lite` database.

The combined script is generated mechanically from the authoritative manifest by `tools/build_workbench_script.py`. Regenerate it after changing any manifest-listed SQL file.

## Expected validation evidence

The final three scripts list database objects and indexes, verify fixture row counts, run operational reports and an `EXPLAIN FORMAT=TREE`, and execute positive and expected-failure smoke tests. Expected-failure tests cover unavailable checkout, duplicate return, unassigned-director access, and audit tampering.

## Security and data handling

All sample identities use the reserved `.test` domain and are fictional. Representative MySQL roles receive access to views and controlled procedures rather than direct modification of circulation tables. Business-role and row-scope checks are also enforced inside procedures. Audit and inventory-adjustment records reject updates and deletes.
