# Technical Design Document (TDD)

## 1. Project identification

| Item | Information |
|---|---|
| Project title | KOHA-Lite Inventory Management for Little Free Libraries |
| Prepared by | Matthew Li and Yash Shashtri |
| Course/section | 01:198:437:01 |
| Date | October 16, 2026 |
| Version | 1.0 |

## 2. Design overview

KOHA-Lite is a relational database for recorded circulation across participating Little Free Libraries. It stores users and roles, director-library assignments, libraries, book titles, individual copies, loans, donations, explicit visits, inventory corrections, and audit events. MySQL 8.0/InnoDB provides primary and foreign keys, unique and check constraints, generated columns, views, stored routines, triggers, transactions, locking reads, roles, and grants.

The implementation contains fourteen base tables. Availability and quantity are derived from physical-copy rows. State-changing workflows use stored procedures so authorization, validation, the business change, and its audit record occur through one controlled operation. Checkout locks the selected copy using `SELECT ... FOR UPDATE`; a generated unique key independently limits each copy to one active loan.

## 3. Technical environment

| Component | Selected technology/tool | Purpose |
|---|---|---|
| Database management system | MySQL Server 8.0+ / InnoDB | Relational storage, constraints, transactions, routines, roles |
| Database client/IDE | MySQL command-line client; MySQL Workbench | Build, query, and inspect the database |
| Modeling tool | draw.io-compatible XML; Mermaid review source | Create the ERD and portable diagram source |
| Documentation | Markdown and PDF | Versionable sources and submission artifacts |
| Build | PowerShell, Git, exact Git tag | Reproducible fresh database creation |
| Source control, if used | Git/GitHub | Immutable release tag and history |
| Operating environment | Windows; MySQL 8.x | Primary classroom/test platform |

## 4. Architecture and scope

The project uses one database-centered MySQL schema named `koha_lite`. A future application would call controlled procedures and read protected views. Individual patrons are represented by business records, not necessarily individual MySQL accounts. Representative MySQL roles demonstrate database permissions, while `UserRole` and `DirectorLibrary` enforce business identity and row scope.

Included artifacts are schema objects, routines, triggers, indexes, roles/grants, fictional sample data, reports, validation queries, smoke tests, documentation, ERD, and an exact-tag build script. A web/mobile UI, geographic map, production identity provider, notifications, surveillance, and production backup automation are excluded.

## 5. Entity-relationship design

The editable diagram is `docs/KOHA-Lite_ERD.drawio`; `docs/KOHA-Lite_ERD.mmd` is a reviewable equivalent.

| Entity | Purpose | Primary key | Important relationships |
|---|---|---|---|
| UserAccount | Synthetic project user | UserID | Roles, director assignments, loans, donations, visits, adjustments, audit events |
| BusinessRole | Approved business role | RoleCode | Many-to-many with users through UserRole |
| UserRole | User/role assignment | UserID + RoleCode | Resolves UserAccount-to-BusinessRole many-to-many |
| Library | Participating physical location | LibraryID | Copies, circulation locations, visits, donations, assignments |
| DirectorLibrary | Director's managed library | UserID + LibraryID | Resolves director-to-library many-to-many |
| BookCategory | Controlled title classification | CategoryID | One category to many titles |
| BookTitle | Shared bibliographic description | BookTitleID | One title to many copies and donation items |
| BookCopy | Individually tracked physical copy | BookCopyID | One title; current library; loan and adjustment history |
| Loan | Checkout/return lifecycle | LoanID | One copy, one patron, checkout and optional return libraries/actors |
| Donation | Donation submission/decision | DonationID | One donor, one receiving library, many donation items |
| DonationItem | Donated title and quantities | DonationItemID | One donation, one title, zero or more accepted copies |
| Visit | Explicit patron visit | VisitID | One patron, library, and recording actor |
| InventoryAdjustment | Immutable reconciliation event | AdjustmentID | One copy and director; prior/new state |
| AuditEvent | Append-only business-event evidence | AuditEventID | One actor; optional library; polymorphic affected record identifier |

Cardinality summary:

- One user has zero-to-many `UserRole` rows; one business role has zero-to-many user assignments.
- One director and one library each have zero-to-many `DirectorLibrary` assignments.
- One category has many titles; one title has many physical copies.
- One copy has many historical loans but at most one active loan.
- One patron has many loans and visits.
- One donation has one or more donation items; one accepted donation item can create many copies.
- One copy has many inventory adjustments and audit events over time.

## 6. Relational schema

```text
BusinessRole(RoleCode PK, RoleName UQ, RoleDescription)
UserAccount(UserID PK, DisplayName, Email UQ, IsActive, CreatedAt)
UserRole(UserID PK/FK -> UserAccount, RoleCode PK/FK -> BusinessRole, AssignedAt)
Library(LibraryID PK, LibraryName UQ, AddressLine1, City, StateCode, PostalCode, LibraryStatus, CreatedAt)
DirectorLibrary(UserID PK/FK -> UserAccount, LibraryID PK/FK -> Library, AssignedAt)
BookCategory(CategoryID PK, CategoryName UQ, CategoryDescription)
BookTitle(BookTitleID PK, ISBN13 UQ, Title, AuthorName, CategoryID FK -> BookCategory, CreatedAt)
Donation(DonationID PK, DonorUserID FK, ReceivingLibraryID FK, DonationStatus,
         SubmittedAt, DecidedAt, DecidedByUserID FK, DecisionNote)
DonationItem(DonationItemID PK, DonationID FK, BookTitleID FK,
             OfferedQuantity, AcceptedQuantity, UQ(DonationID, BookTitleID))
BookCopy(BookCopyID PK, BookTitleID FK, CurrentLibraryID FK, CopyStatus,
         RegistrationSource, DonationItemID FK, RegisteredByUserID FK, RegisteredAt)
Loan(LoanID PK, BookCopyID FK, PatronUserID FK, CheckoutLibraryID FK,
     CheckoutRecordedByUserID FK, CheckoutAt, ReturnLibraryID FK,
     ReturnRecordedByUserID FK, ReturnedAt, LoanStatus,
     ActiveBookCopyID GENERATED UQ)
Visit(VisitID PK, PatronUserID FK, LibraryID FK, VisitedAt,
      RecordedByUserID FK, RecordingMethod)
InventoryAdjustment(AdjustmentID PK, BookCopyID FK, DirectorUserID FK,
                    PreviousLibraryID FK, NewLibraryID FK,
                    PreviousStatus, NewStatus, Reason, AdjustedAt)
AuditEvent(AuditEventID PK, ActorUserID FK, EventType, EntityType, EntityID,
           EventTimestamp, Outcome, LibraryID FK, ContextData JSON)
```

## 7. Table and attribute specifications

### BusinessRole

One row represents an approved business role.

| Column | Type | Null | Constraint/meaning |
|---|---|---:|---|
| RoleCode | VARCHAR(20) | No | PK; stable code such as PATRON |
| RoleName | VARCHAR(60) | No | UNIQUE display name |
| RoleDescription | VARCHAR(255) | No | Role purpose |

### UserAccount

One row represents a fictional registered user.

| Column | Type | Null | Constraint/meaning |
|---|---|---:|---|
| UserID | BIGINT UNSIGNED | No | PK, auto-increment |
| DisplayName | VARCHAR(120) | No | Nonblank synthetic name |
| Email | VARCHAR(255) | No | UNIQUE synthetic email; simple format check |
| IsActive | BOOLEAN | No | Active users may operate; default true |
| CreatedAt | DATETIME(6) | No | Creation time; default current timestamp |

### UserRole

One row assigns one business role to one user.

| Column | Type | Null | Constraint/meaning |
|---|---|---:|---|
| UserID | BIGINT UNSIGNED | No | PK/FK to UserAccount |
| RoleCode | VARCHAR(20) | No | PK/FK to BusinessRole |
| AssignedAt | DATETIME(6) | No | Assignment time |

### Library

One row represents one participating New Jersey Little Free Library.

| Column | Type | Null | Constraint/meaning |
|---|---|---:|---|
| LibraryID | BIGINT UNSIGNED | No | PK, auto-increment |
| LibraryName | VARCHAR(150) | No | UNIQUE, nonblank name |
| AddressLine1 | VARCHAR(150) | No | Fictional/demo address line |
| City | VARCHAR(100) | No | City |
| StateCode | CHAR(2) | No | CHECK NJ |
| PostalCode | VARCHAR(10) | No | Postal code |
| LibraryStatus | ENUM | No | ACTIVE or INACTIVE |
| CreatedAt | DATETIME(6) | No | Creation time |

### DirectorLibrary

One row authorizes one director for one library.

| Column | Type | Null | Constraint/meaning |
|---|---|---:|---|
| UserID | BIGINT UNSIGNED | No | PK/FK to UserAccount |
| LibraryID | BIGINT UNSIGNED | No | PK/FK to Library |
| AssignedAt | DATETIME(6) | No | Assignment time |

### BookCategory

| Column | Type | Null | Constraint/meaning |
|---|---|---:|---|
| CategoryID | SMALLINT UNSIGNED | No | PK, auto-increment |
| CategoryName | VARCHAR(80) | No | UNIQUE category name |
| CategoryDescription | VARCHAR(255) | Yes | Optional explanation |

### BookTitle

One row stores bibliographic information shared by multiple copies.

| Column | Type | Null | Constraint/meaning |
|---|---|---:|---|
| BookTitleID | BIGINT UNSIGNED | No | PK, auto-increment |
| ISBN13 | CHAR(13) | Yes | UNIQUE when supplied; 13-digit check |
| Title | VARCHAR(255) | No | Nonblank title |
| AuthorName | VARCHAR(180) | No | Nonblank author/display attribution |
| CategoryID | SMALLINT UNSIGNED | No | FK to BookCategory |
| CreatedAt | DATETIME(6) | No | Creation time |

### Donation

One row represents a submission and its final decision.

| Column | Type | Null | Constraint/meaning |
|---|---|---:|---|
| DonationID | BIGINT UNSIGNED | No | PK, auto-increment |
| DonorUserID | BIGINT UNSIGNED | No | FK to UserAccount |
| ReceivingLibraryID | BIGINT UNSIGNED | No | FK to Library |
| DonationStatus | ENUM | No | SUBMITTED, ACCEPTED, or REJECTED |
| SubmittedAt | DATETIME(6) | No | Submission time |
| DecidedAt | DATETIME(6) | Yes | Required after decision |
| DecidedByUserID | BIGINT UNSIGNED | Yes | FK; required after decision |
| DecisionNote | VARCHAR(500) | Yes | Acceptance/rejection context |

### DonationItem

One row represents one title offered within a donation.

| Column | Type | Null | Constraint/meaning |
|---|---|---:|---|
| DonationItemID | BIGINT UNSIGNED | No | PK, auto-increment |
| DonationID | BIGINT UNSIGNED | No | FK to Donation |
| BookTitleID | BIGINT UNSIGNED | No | FK to BookTitle |
| OfferedQuantity | SMALLINT UNSIGNED | No | CHECK greater than zero |
| AcceptedQuantity | SMALLINT UNSIGNED | Yes | Null before decision; not greater than offered |

`UNIQUE(DonationID, BookTitleID)` prevents duplicate title lines.

### BookCopy

One row represents one physical copy.

| Column | Type | Null | Constraint/meaning |
|---|---|---:|---|
| BookCopyID | BIGINT UNSIGNED | No | PK, auto-increment |
| BookTitleID | BIGINT UNSIGNED | No | FK to BookTitle |
| CurrentLibraryID | BIGINT UNSIGNED | Yes | FK to recorded location; required for available/on-loan copies |
| CopyStatus | ENUM | No | AVAILABLE, ON_LOAN, LOST, or RETIRED |
| RegistrationSource | ENUM | No | DIRECT or DONATION |
| DonationItemID | BIGINT UNSIGNED | Yes | FK required only for donation source |
| RegisteredByUserID | BIGINT UNSIGNED | No | FK to registering director |
| RegisteredAt | DATETIME(6) | No | Registration time |

### Loan

One row represents one checkout and its eventual return.

| Column | Type | Null | Constraint/meaning |
|---|---|---:|---|
| LoanID | BIGINT UNSIGNED | No | PK, auto-increment |
| BookCopyID | BIGINT UNSIGNED | No | FK to BookCopy |
| PatronUserID | BIGINT UNSIGNED | No | FK to borrowing patron |
| CheckoutLibraryID | BIGINT UNSIGNED | No | FK to originating library |
| CheckoutRecordedByUserID | BIGINT UNSIGNED | No | FK to patron/director actor |
| CheckoutAt | DATETIME(6) | No | Checkout timestamp |
| ReturnLibraryID | BIGINT UNSIGNED | Yes | FK; populated at return |
| ReturnRecordedByUserID | BIGINT UNSIGNED | Yes | FK; populated at return |
| ReturnedAt | DATETIME(6) | Yes | Return timestamp not before checkout |
| LoanStatus | ENUM | No | ACTIVE or RETURNED |
| ActiveBookCopyID | BIGINT UNSIGNED | Yes | Generated copy ID only for ACTIVE rows; UNIQUE |

### Visit

| Column | Type | Null | Constraint/meaning |
|---|---|---:|---|
| VisitID | BIGINT UNSIGNED | No | PK, auto-increment |
| PatronUserID | BIGINT UNSIGNED | No | FK to patron |
| LibraryID | BIGINT UNSIGNED | No | FK to visited library |
| VisitedAt | DATETIME(6) | No | Explicit visit time |
| RecordedByUserID | BIGINT UNSIGNED | No | FK to patron/director actor |
| RecordingMethod | ENUM | No | PATRON_SELF or DIRECTOR |

### InventoryAdjustment

One immutable row records a director's reconciliation.

| Column | Type | Null | Constraint/meaning |
|---|---|---:|---|
| AdjustmentID | BIGINT UNSIGNED | No | PK, auto-increment |
| BookCopyID | BIGINT UNSIGNED | No | FK to affected copy |
| DirectorUserID | BIGINT UNSIGNED | No | FK to actor |
| PreviousLibraryID | BIGINT UNSIGNED | Yes | FK to prior location |
| NewLibraryID | BIGINT UNSIGNED | Yes | FK to corrected location |
| PreviousStatus | ENUM | No | Prior copy status |
| NewStatus | ENUM | No | Corrected copy status |
| Reason | VARCHAR(500) | No | At least five non-space characters |
| AdjustedAt | DATETIME(6) | No | Adjustment time |

### AuditEvent

One immutable row records a business event.

| Column | Type | Null | Constraint/meaning |
|---|---|---:|---|
| AuditEventID | BIGINT UNSIGNED | No | PK, auto-increment |
| ActorUserID | BIGINT UNSIGNED | No | FK to actor |
| EventType | VARCHAR(60) | No | Stable nonblank event code |
| EntityType | VARCHAR(60) | No | Affected entity type |
| EntityID | BIGINT UNSIGNED | No | Affected record identifier |
| EventTimestamp | DATETIME(6) | No | Event time |
| Outcome | ENUM | No | SUCCEEDED or REJECTED; implemented business events use SUCCEEDED |
| LibraryID | BIGINT UNSIGNED | Yes | Optional FK for row-scope reporting |
| ContextData | JSON | Yes | Relevant IDs and prior/new context; no secrets |

## 8. Normalization analysis

| Normal form | Design check | Evidence |
|---|---|---|
| 1NF | Atomic columns and no repeating groups | Roles, director assignments, donation items, copies, loans, and visits are separate rows rather than lists in User or Library. |
| 2NF | Non-key values depend on the complete key | Composite-key tables UserRole and DirectorLibrary contain only facts about the complete assignment. |
| 3NF | Non-key values do not depend on other non-key values | Category description is in BookCategory; bibliographic data is in BookTitle; copy state is in BookCopy; library names are not copied into Loan. |

Stored copy quantity was deliberately rejected: counts are derived from `BookCopy`, preventing a stored quantity from disagreeing with individual copy state. `BookTitle` is separated from `BookCopy`, so three copies share one title without duplicating title/author/category. History tables retain foreign keys and event facts rather than mutable descriptive copies.

## 9. Integrity, validation, and business-rule enforcement

| Rule | Technical implementation | Verification |
|---|---|---|
| BR-01 unique records/assignments | PKs, composite PKs, unique email/name/ISBN/title-line constraints | Duplicate inserts fail |
| BR-02 title and location integrity | NOT NULL title FK and copy-location CHECK | Invalid FK/location-state insert fails |
| BR-03 one active loan | Generated `ActiveBookCopyID` plus UNIQUE | Concurrent/duplicate checkout test |
| BR-04 available active-library checkout | `sp_CheckoutCopy`, role checks, locked copy read | Available succeeds; unavailable rejected |
| BR-05 atomic checkout | InnoDB transaction and EXIT handler rollback | Loan/copy/audit state checked together |
| BR-06 valid return | `sp_ReturnCopy` active-state and return-library validation | Valid cross-library return; duplicate rejected |
| BR-07 patron eligibility | `fn_HasRole` and active-user condition | Inactive/non-patron rejected |
| BR-08 scoped director | `fn_DirectorManagesLibrary` in director procedures | Unassigned director rejected |
| BR-09 donation quantities | CHECK constraints; acceptance copies offered quantity | Known donation fixture |
| BR-10 demand definition | COUNT(DISTINCT patron) with required half-open date range | Known report fixture |
| BR-11 inactive library | Procedure checks `LibraryStatus` | New activity rejected after deactivation |
| BR-12 attributable correction | `sp_AdjustInventory`, required reason, immutable row | Prior/new values and audit checked |
| BR-13 append-only audit | No DML grants; UPDATE/DELETE rejection triggers | Tamper test fails as expected |
| BR-14 preserve history | No cascade deletes; controlled state changes | Historical query remains available |
| BR-15 safe retries | State validation, unique active loan, rollback | Duplicate return/checkout changes nothing |

## 10. Database objects and SQL design

| Type | Object | Purpose | Related requirements |
|---|---|---|---|
| View | vw_AvailableCatalog | Available counts by library/title/category | FR-02, RQ-01 |
| View | vw_ActiveLoan | Current loans and checkout context | FR-03, RQ-02 |
| View | vw_LoanHistory | Complete circulation history | FR-07, RQ-03 |
| View | vw_Inventory | Copy state, location, and active-loan flag | FR-09, RQ-06 |
| View | vw_DonationStatus | Donation totals and state | FR-05, RQ-07 |
| View | vw_AuditHistory | Human-readable append-only evidence | FR-11, RQ-08 |
| Function | fn_HasRole | Active-user business-role check | FR-03, FR-06, FR-10 |
| Function | fn_DirectorManagesLibrary | Scoped director entitlement | FR-01, FR-05, FR-09, FR-12 |
| Procedure | sp_RegisterBookCopy | Controlled direct copy registration | FR-01 |
| Procedure | sp_CheckoutCopy | Atomic, concurrency-safe checkout | FR-03, FR-10, FR-13 |
| Procedure | sp_ReturnCopy | Atomic cross-library return | FR-04, FR-10, FR-13 |
| Procedure | sp_RecordVisit | Patron/director explicit check-in | FR-06 |
| Procedures | sp_Submit/Accept/RejectDonation | Donation lifecycle and accepted copies | FR-05 |
| Procedure | sp_AdjustInventory | Attributable reconciliation | FR-09 |
| Procedure | sp_SetLibraryStatus | Scoped operational status change | FR-12 |
| Triggers | AuditEvent/InventoryAdjustment no-update/no-delete | Append-only evidence | FR-09, FR-11 |
| Indexes | Copy, loan, visit, donation, adjustment, audit indexes | Join/filter/order access paths | RQ-01 through RQ-08 |

The important checkout index path begins with copy identity for the locked point lookup. Patron history uses `(PatronUserID, CheckoutAt DESC)`, and available inventory uses `(CurrentLibraryID, CopyStatus, BookTitleID)`. Demand uses the checkout-library/time data; its performance should be evaluated with `EXPLAIN` as sample volume increases.

## 11. Query and report design

| Query | Main tables | SQL features | Expected result |
|---|---|---|---|
| RQ-01 available catalog | Library, BookCopy, BookTitle, BookCategory | JOIN, WHERE, COUNT, GROUP BY, ORDER BY | Available title counts for one library/category |
| RQ-02 active loans | Loan, BookCopy, BookTitle, Library | JOIN, status filter, patron filter | Patron's active copies oldest first |
| RQ-03 borrowing history | Loan, BookCopy, BookTitle, two Library joins | JOIN, optional date range, ORDER BY | Checkout/return lifecycle |
| RQ-04 title demand | Loan, BookCopy, BookTitle | required date filter, optional library, COUNT DISTINCT, GROUP BY | Distinct patron and checkout counts |
| RQ-05 visit history | Visit, Library | patron/date filter, descending time | Explicit visits |
| RQ-06 inventory | BookCopy, BookTitle, Library, active Loan | joins, status/filter | Recorded copy state for assigned library |
| RQ-07 donations | Donation, DonationItem, BookTitle, Library | joins, aggregation, status filter | Offered/accepted quantities and state |
| RQ-08 audit | AuditEvent, UserAccount, Library | scoped filter, JSON context, time order | Attributable history |

The validation script implements RQ-04 with a half-open interval (`>= start`, `< end`) to avoid overlapping date windows, and includes `EXPLAIN FORMAT=TREE` for patron loan history.

## 12. Security, privacy, and backup assumptions

- All sample names, addresses, and `.test` emails are fictional.
- Business authorization is enforced with `UserRole`, `DirectorLibrary`, functions, and stored procedures.
- Representative MySQL roles receive SELECT on protected views and EXECUTE on procedures; they receive no direct circulation-table modification rights.
- Audit and inventory-adjustment rows reject update and delete operations.
- Credentials are supplied via environment variables and never committed or written to logs.
- InnoDB transactions roll back incomplete multi-table workflows. The build stops on the first failed script.
- The build refuses to replace an existing database unless `ALLOW_DATABASE_RECREATE=YES` is explicitly set.
- Production encryption, identity federation, scheduled backup/restore testing, retention, and high availability remain outside this course implementation. A production deployment would require them.

## 13. Test plan and acceptance criteria

| Test ID | Requirement/rule | Test action | Expected result | Actual result/pass-fail |
|---|---|---|---|---|
| T-01 | FR-01/BR-08 | Assigned director registers copy | Copy and audit inserted | Procedure and fixture/query |
| T-02 | FR-01/BR-08 | Unassigned director registers copy | Rejected; no copy | Smoke test PASS |
| T-03 | FR-02 | Query known catalog fixture | Expected available counts | vw_AvailableCatalog |
| T-04 | FR-03/BR-05 | Checkout available copy | One loan; copy ON_LOAN; audit | Atomic-state PASS |
| T-05 | FR-03/BR-03 | Checkout already loaned copy | Rejected; one active loan | Failure test PASS |
| T-06 | FR-04/BR-06 | Return to different library | Loan returned; copy available there | Cross-library PASS |
| T-07 | FR-13 | Repeat completed return | Rejected; no extra change | Failure test PASS |
| T-08 | FR-05/BR-09 | Accept donation of two copies | Two linked copies; accepted count two | Donation PASS |
| T-09 | FR-06 | Self/director visit recording | Correct method, actor, patron, library | Seed/query evidence |
| T-10 | FR-07/FR-10 | Access another patron outside scope | Protected interface rejects/does not grant table DML | Role/grant inspection |
| T-11 | FR-08/BR-10 | Run Sept. fixture demand | Title 1 has two distinct patrons | Data-validation query |
| T-12 | FR-09/BR-12 | Adjust non-loaned copy with reason | Copy, adjustment, audit agree | Procedure/query |
| T-13 | FR-11/BR-13 | Update audit event | Trigger rejects update | Failure test PASS |
| T-14 | FR-12/BR-11 | Deactivate assigned library and submit activity | New activity rejected; history retained | Procedure/query |
| T-15 | Build | Fresh exact-tag build | All manifest scripts and validation succeed | Build log |

The repository contains expected-result SQL. The database build completed successfully on MySQL 8.0.42; individual PASS/FAIL result rows should be captured during the recorded demonstration.

## 14. Requirement traceability

| FR | Tables/relationships | Enforcement/objects | Report/test evidence |
|---|---|---|---|
| FR-01 | BookTitle -> BookCopy -> Library; DirectorLibrary | sp_RegisterBookCopy, FK, scoped function | T-01, T-02, RQ-06 |
| FR-02 | Library -> BookCopy -> BookTitle -> Category | vw_AvailableCatalog, copy index | T-03, RQ-01 |
| FR-03 | Patron -> Loan -> BookCopy/Library | sp_CheckoutCopy, lock, transaction, active-copy UQ | T-04, T-05, RQ-02 |
| FR-04 | Loan -> return Library; BookCopy current Library | sp_ReturnCopy, transaction | T-06, T-07, RQ-03 |
| FR-05 | Donor -> Donation -> Item -> Title/Copy | donation procedures and checks | T-08, RQ-07 |
| FR-06 | Patron -> Visit -> Library/actor | sp_RecordVisit | T-09, RQ-05 |
| FR-07 | Patron -> Loan/Visit; DirectorLibrary | protected views, roles, scoped design | T-10, RQ-03/RQ-05 |
| FR-08 | Loan -> Copy -> Title/Library | date-range COUNT DISTINCT query | T-11, RQ-04 |
| FR-09 | Copy -> InventoryAdjustment -> Director | sp_AdjustInventory, immutable triggers | T-12, RQ-06/RQ-08 |
| FR-10 | All transactional relationships | functions, procedures, checks, rollback | T-02, T-05, T-07, T-10 |
| FR-11 | Actor -> AuditEvent -> affected record | procedure audit inserts, immutable triggers | T-13, RQ-08 |
| FR-12 | Library status and historical FKs | sp_SetLibraryStatus, procedure checks | T-14 |
| FR-13 | Loan and generated active-copy key | state validation, UNIQUE, locking read | T-05, T-07 |
