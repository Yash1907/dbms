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

## Use the tagged release

The submitted midterm release is tagged `v1.0.0`. A tag identifies the exact
version of every database file used for that release, so later changes on the
`main` branch do not silently change the build.

Clone the repository and switch to that release with PowerShell:

```powershell
git clone https://github.com/Yash1907/dbms.git
Set-Location dbms
git fetch --tags
git checkout v1.0.0
git describe --exact-match --tags HEAD
```

The final command should print `v1.0.0`. Git may say that the checkout is in a
"detached HEAD" state. That is normal when using a tag: it means you are viewing
the fixed release instead of a moving development branch.

## Set up the database from scratch

1. Install MySQL Server 8.0 or newer and MySQL Workbench.
2. Clone and check out `v1.0.0` using the commands above. If using a ZIP file,
   download the `v1.0.0` source archive from the repository's Releases or Tags
   page and extract it.
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

## Build the tagged release with PowerShell

`build/build_database.ps1` is an automated alternative to Workbench. It clones
the requested tag into a temporary working folder, verifies that Git resolved
that exact tag, runs the SQL files in manifest order, and saves build and error
logs under `.build-work`.

Before running it, make sure `git` and the MySQL command-line client are
available:

```powershell
git --version
mysql --version
```

If `mysql` is not recognized but MySQL Server is installed, add the MySQL
Server `bin` folder to `PATH`, or use the Workbench method above.

Set the connection information for the current PowerShell window. Replace the
password with the administrator password for your MySQL installation:

```powershell
$env:DB_HOST = "127.0.0.1"
$env:DB_PORT = "3306"
$env:DB_ADMIN_USER = "root"
$env:DB_ADMIN_PASSWORD = "YOUR_MYSQL_PASSWORD"
```

Run the exact tagged build from the repository root:

```powershell
.\build\build_database.ps1 `
  -Owner Yash1907 `
  -Repository dbms `
  -VersionTag v1.0.0
```

A successful log ends with a line containing:

```text
BUILD SUCCEEDED tag=v1.0.0 commit=b663e59ca3250f0be17a814a0f8b0e3a6fe21c51 database=koha_lite
```

The script refuses to overwrite an existing `koha_lite` database. To replace
it intentionally, first back up anything you need, then opt in for that one
PowerShell session and rerun the command:

```powershell
$env:ALLOW_DATABASE_RECREATE = "YES"
```

Remove the password and replacement setting from the current shell when the
build is finished:

```powershell
Remove-Item Env:DB_ADMIN_PASSWORD
Remove-Item Env:ALLOW_DATABASE_RECREATE -ErrorAction SilentlyContinue
```

## Verify the installed database

Whether the database was built in Workbench or with PowerShell, run:

```sql
USE koha_lite;

SELECT VERSION() AS MySQLVersion, DATABASE() AS CurrentDatabase;

SELECT COUNT(*) AS BaseTableCount
FROM information_schema.tables
WHERE table_schema = 'koha_lite'
  AND table_type = 'BASE TABLE';

SELECT *
FROM vw_AvailableCatalog
ORDER BY LibraryName, Title;
```

The current database should be `koha_lite`, the base-table count should be 14,
and the available-catalog query should return the included sample data.
