# KOHA-Lite database project

KOHA-Lite is a MySQL 8 database for tracking books across participating Little Free Libraries. It records individual book copies, checkouts, returns, donations, visits, director assignments, inventory fixes, reports, and audit history. [Watch the midterm demo](https://youtu.be/ZkD1lQ0C_84).

## Deliverables

- `docs/FRD.md`, `output/docx/KOHA-Lite_FRD.docx`, and `output/pdf/KOHA-Lite_FRD.pdf`: functional requirements in source, Google Docs import, and submission formats
- `docs/TDD.md`, `output/docx/KOHA-Lite_TDD.docx`, and `output/pdf/KOHA-Lite_TDD.pdf`: technical design in source, Google Docs import, and submission formats
- `docs/KOHA-Lite_ERD.drawio` and `docs/KOHA-Lite_ERD.png`: editable draw.io entity-relationship model and exported image
- `docs/KOHA-Lite_ERD.mmd` and `output/pdf/KOHA-Lite_ERD.pdf`: reviewable ERD source and PDF
- `database/`: ordered schema, programmability, security, seed, and validation scripts
- `build/build_database.ps1`: exact-tag Windows build script
- `build/koha_lite_workbench_build.sql`: single-file local Workbench build and validation

## Required platform and tools

- MySQL Server 8.0 or newer
- MySQL Workbench
- An administrator login, such as the local `root` account
- Git, if cloning the repository instead of downloading it as a ZIP file

## Set up the database from scratch

1. Install MySQL Server 8.0 or newer and MySQL Workbench.
2. Clone this repository, or download it from GitHub and extract the ZIP file.
3. Start MySQL Server.
4. Open MySQL Workbench and connect using an administrator account that may create databases, procedures, functions, triggers, roles, and permissions.
5. Open `build/koha_lite_workbench_build.sql` from the repository's `build` folder.
6. Run the entire file using Workbench's lightning-bolt button. Do not run only the selected line.
7. Wait for the final result to show:

```text
KOHA_LITE_BUILD_COMPLETE | koha_lite | your MySQL version
```

8. In Workbench's Schemas panel, click refresh. The new `koha_lite` database should appear.
9. Run this quick check:

```sql
USE koha_lite;
SELECT * FROM vw_AvailableCatalog ORDER BY LibraryName, Title;
```

The build file creates the database, tables, keys, indexes, views, saved SQL actions, security rules, sample data, and tests. The sample data is included so the reports and workflows can be tried immediately.

The build will stop if a database named `koha_lite` already exists. This prevents it from deleting an existing database by accident. If you intentionally want a completely fresh copy, back up anything you need and run this before running the build again:

```sql
DROP DATABASE koha_lite;
```
