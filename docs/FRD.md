# Functional Requirements Document (FRD)

## 1. Project identification

| Item | Information |
|---|---|
| Project title | KOHA-Lite Inventory Management for Little Free Libraries |
| Prepared by | Matthew Li and Yash Shashtri |
| Course/section | 01:198:437:01 |
| Date | October 16, 2026 |
| Version | 2.1 |

## 2. Business problem and project purpose

Participating Little Free Libraries in New Jersey need a shared database for recording the circulation and location of their books. The libraries currently rely on an honor system, so directors cannot reliably determine which recorded books are available, which copies are on loan, where a returned copy is located, or which titles are in demand.

KOHA-Lite models circulation within participating libraries. Registered patrons and authorized directors record every checkout and return. Inventory represents recorded activity rather than independently verified physical inventory. Directors can reconcile differences between recorded and observed inventory for libraries assigned to them, and every reconciliation retains an attributable audit record.

The project will provide a normalized MySQL database that tracks physical book copies, circulation, donations, visits, director assignments, inventory corrections, and operational reports. It will not include a public website, mobile application, geographic map, cameras, automated physical surveillance, or production identity management.

## 3. Scope

| In scope | Out of scope |
|---|---|
| Registered fictional users with patron, donor, or director roles | Anonymous or unrecorded borrowing, returns, or donations |
| Participating libraries and their operational status | Geographic map rendering, route planning, or GPS tracking |
| Book titles and individually identified physical copies | Book-condition grading, valuation, pricing, fines, or sales |
| Recorded availability and current library for every copy | Guaranteeing that recorded inventory exactly matches physical inventory |
| Checkout and mandatory-return workflows | Permanent taking of a checked-out copy |
| Returns to the originating or another participating library | Waiting lists, reservations, or interlibrary shipping |
| Donation submission and director acceptance | Purchasing and supplier management |
| Explicit patron library visits | Passive surveillance or automatic visit detection |
| Director reconciliation of recorded inventory drift | Public-facing web or mobile application development |
| Role-based access, audit history, reports, and database tests | Production authentication, notifications, and enterprise backup automation |

## 4. Stakeholders and user roles

One user may hold multiple roles. A director may manage one or more assigned libraries. Director authority is scoped to assigned libraries; it is not automatically global.

| Role | Responsibilities | Database needs |
|---|---|---|
| Patron | Records personal checkouts, returns, and visits; reviews personal history | Available-book catalog, own active loans, own borrowing history, own visit history |
| Donor | Submits donations and reviews aggregate demand information | Donation submission/status and aggregate demand reports |
| Director | Maintains assigned libraries, records circulation for patrons, accepts donations, and reconciles inventory | Assigned-library inventory, controlled procedures, operational reports, and audit history |

### Permission matrix

| Operation | Patron | Donor | Director |
|---|---:|---:|---:|
| View available books | Yes | Yes | Yes |
| View aggregate demand | Yes | Yes | Yes |
| View personal borrowing and visit history | Own records | Only when also a patron | Own records; another patron only for an assigned-library operational task |
| Record checkout or return | Own activity | Only when also a patron | For patrons at assigned libraries |
| Record a visit | Own visit | Only when also a patron | For patrons at assigned libraries |
| Submit a donation | Yes | Yes | Yes |
| Accept or reject a donation | No | No | Assigned receiving libraries only |
| Register a physical copy | No | No | Assigned libraries only |
| Reconcile inventory drift | No | No | Assigned libraries only |
| Change an assigned library's operational status | No | No | Assigned libraries only |
| Modify or delete audit history | No | No | No |

Roles above are business roles stored in the schema. MySQL roles and grants provide a second enforcement layer for representative database users; the project does not require one MySQL account per patron.

## 5. Functional requirements

| ID | Functional requirement | Priority | Related data/entities |
|---|---|---|---|
| FR-01 | An authorized director shall register an individual physical book copy at a library assigned to that director. | High | UserAccount, DirectorLibrary, BookTitle, BookCopy, Library |
| FR-02 | The system shall list available copies at a selected active library, including title, author, category, and available-copy count. | High | Library, BookTitle, BookCategory, BookCopy |
| FR-03 | A registered patron, or a director acting for that patron at an assigned library, shall check out an available copy. A successful checkout shall create one active loan and mark the copy on loan in one transaction. | High | UserAccount, UserRole, BookCopy, Loan, Library |
| FR-04 | A registered patron, or a director acting for that patron, shall return a copy with an active loan. A successful return shall close the loan, mark the copy available, and set its current location to the selected participating return library in one transaction. | High | Loan, BookCopy, Library |
| FR-05 | A registered user shall submit a donation to a selected active library, and an assigned director shall accept or reject it. Accepted physical copies shall be individually registered and linked to the donation. | Medium | Donation, DonationItem, BookTitle, BookCopy, Library |
| FR-06 | A patron, or an assigned director acting for the patron, shall record an explicit library visit with its library, timestamp, and recording actor. | Medium | Visit, UserAccount, Library |
| FR-07 | A patron shall retrieve only that patron's borrowing and visit history. A director may retrieve patron activity only when it concerns a library assigned to that director. | High | Loan, Visit, DirectorLibrary |
| FR-08 | The system shall report demand as the number of distinct patrons who checked out each title during a required date range, optionally filtered to one library, ordered from greatest to least demand. | Medium | Loan, BookCopy, BookTitle, Library |
| FR-09 | An assigned director shall reconcile a recorded copy's location or status when observed inventory differs, supplying a nonblank reason and preserving the prior and new values. | High | InventoryAdjustment, BookCopy, DirectorLibrary |
| FR-10 | The system shall reject unauthorized actions, inactive users, inactive libraries, unavailable-copy checkouts, returns without active loans, and invalid state transitions without leaving partial circulation or inventory changes. | High | All transactional entities |
| FR-11 | The system shall create append-only audit evidence for successful state-changing business operations, including actor, event, affected record, timestamp, and relevant context. | High | AuditEvent |
| FR-12 | An assigned director shall mark that library active or inactive through a controlled operation. Inactive libraries shall retain history but shall not accept new checkout, return, visit, donation, or copy-registration activity. | Medium | Library, DirectorLibrary, AuditEvent |
| FR-13 | A repeated checkout or return request that conflicts with the current state shall be rejected without creating another loan, return, or inventory change. | High | Loan, BookCopy, AuditEvent |

## 6. Data requirements

| Data subject | Information to store | Identifier |
|---|---|---|
| User account | Synthetic display name, synthetic email, active status, creation time | UserID |
| Role assignment | User and business role | UserID + RoleCode |
| Library | Name, address, operational status | LibraryID |
| Director assignment | Director and managed library | UserID + LibraryID |
| Book category | Category name and description | CategoryID |
| Book title | ISBN when available, title, author, category | BookTitleID |
| Book copy | Title, current library, status, registration source and time | BookCopyID |
| Loan | Copy, patron, checkout library/actor/time, return library/actor/time, state | LoanID |
| Donation | Donor, receiving library, submission state, decision actor/time | DonationID |
| Donation item | Donation, title, offered quantity, accepted quantity | DonationItemID |
| Visit | Patron, library, visit time, recording actor and method | VisitID |
| Inventory adjustment | Copy, director, prior/new status and location, reason, time | AdjustmentID |
| Audit event | Actor, event type, entity, record identifier, timestamp, outcome, context | AuditEventID |

All identities and contact values used for implementation and demonstration are synthetic. Price is not stored because the system does not perform valuation, purchasing, fines, insurance, or sales. Availability and quantity are derived from individual copy records rather than maintained as an independently editable quantity.

## 7. Business rules and validation rules

| ID | Business rule | Planned database enforcement |
|---|---|---|
| BR-01 | Every persistent record has a unique identifier; role and assignment pairs cannot be duplicated. | Primary keys and UNIQUE constraints |
| BR-02 | Every physical copy belongs to exactly one book title and has at most one current library. | NOT NULL title FK; nullable library FK only for retired/lost states |
| BR-03 | A copy may have at most one active loan. | Generated active-copy key with UNIQUE constraint plus controlled procedure |
| BR-04 | Only an AVAILABLE copy at the selected active library may be checked out. | Transactional procedure, locking read, status checks |
| BR-05 | A checkout and its copy-status change succeed or fail together. | InnoDB transaction with rollback handler |
| BR-06 | A return must reference an active loan, and a returned copy becomes AVAILABLE at the participating return library. | Transactional procedure and state validation |
| BR-07 | A patron must be active and have the PATRON role before a checkout, return, or visit is recorded for that patron. | Role-check function and controlled procedures |
| BR-08 | A director may register copies, accept donations, record patron activity, or reconcile inventory only for an assigned library. | Director-assignment function and controlled procedures |
| BR-09 | Donation offered quantity must be positive; accepted quantity must be between zero and offered quantity. | CHECK constraints and acceptance procedure |
| BR-10 | Demand is COUNT(DISTINCT PatronUserID) over successful checkouts in a required date range. | Parameterized report query |
| BR-11 | An inactive library retains existing records but cannot receive new operational activity. | Library-status checks in controlled procedures |
| BR-12 | Inventory reconciliation requires an actor, affected copy, prior/new values, and nonblank reason. | NOT NULL/CHECK constraints and reconciliation procedure |
| BR-13 | Audit events are append-only. | Privileges plus triggers that reject UPDATE and DELETE |
| BR-14 | Completed circulation history is not overwritten or hard-deleted. | No direct DML grants; append/close workflow through procedures |
| BR-15 | A failed or repeated circulation request leaves the database in its prior consistent state. | State checks, unique active-loan constraint, rollback handler |

## 8. Reports and queries

| ID | Report/query name | Purpose | Required result |
|---|---|---|---|
| RQ-01 | Available catalog | Show what patrons can borrow at a selected library | Library and optional category filter; title, author, category, available-copy count; title order |
| RQ-02 | Patron active loans | Show a patron's currently borrowed copies | Authorized patron; copy ID, title, checkout library and time; oldest checkout first |
| RQ-03 | Patron borrowing history | Show a patron's completed and active circulation | Authorized patron and optional date range; copy/title, checkout and return timestamps, libraries, loan state |
| RQ-04 | Title demand | Identify titles used by the most distinct patrons | Required start/end timestamps and optional library; title, distinct-patron count, checkout count; descending demand |
| RQ-05 | Patron visit history | Show explicit visits recorded for a patron | Authorized patron and optional date range; library, visit timestamp, recording method; newest first |
| RQ-06 | Assigned-library inventory | Show recorded inventory for a director's assigned library | Director and assigned library; copy, title, recorded location, copy status, active-loan indicator |
| RQ-07 | Donation status | Show submission and decision progress | Donor or assigned director; donation, receiving library, items, offered/accepted counts, status and decision time |
| RQ-08 | Audit history | Review attributable changes for an authorized scope | Director and assigned library or affected record; actor, event type, timestamp, entity/ID, result and context |

## 9. Assumptions and constraints

- All circulation, returns, donations, and explicit visits covered by the system are recorded; anonymous activity is outside the modeled workflow.
- A checked-out copy is expected to be returned. The project does not impose a due date, overdue fine, or notification because none was requested.
- A return may occur at a participating library different from the checkout library.
- Recorded inventory can drift from observed physical inventory; assigned directors correct drift through an audited reconciliation operation.
- One user may have multiple business roles, and one director may be assigned to multiple libraries.
- Library visits are explicit user/director-recorded events, not inferred from loans and not captured through surveillance.
- The database is implemented for MySQL 8.0 or later using InnoDB and UTF-8 (`utf8mb4`).
- The implementation uses fictional sample identities and does not contain real personal information or credentials.
- A public UI, production authentication service, production backup automation, and physical inventory verification are outside scope.

## 10. Acceptance criteria

| Requirement | Observable acceptance criterion |
|---|---|
| FR-01 | An assigned director registers a copy successfully; an unassigned director's attempt is rejected with no copy inserted. |
| FR-02 | With a known fixture, the selected library catalog returns the expected titles and available-copy counts and excludes on-loan copies. |
| FR-03 | Checkout of an available copy creates exactly one active loan and changes the copy to ON_LOAN in one transaction. Checkout of an unavailable copy changes nothing. |
| FR-04 | Return closes the active loan and makes the copy available at the chosen participating library. A duplicate return changes nothing. |
| FR-05 | A donor submits a donation; an assigned director accepts it; accepted counts and linked individual copies match the approved quantities. |
| FR-06 | Patron self-check-in and director-recorded check-in create visits with the correct patron, library, actor, time, and recording method. |
| FR-07 | A patron can retrieve that patron's history and cannot retrieve another patron's private history through the protected interface. |
| FR-08 | For a fixture containing known checkouts, the demand report returns the expected distinct-patron count for the supplied date range and library filter. |
| FR-09 | An assigned director changes recorded location/status with a reason; the copy and immutable adjustment history show the expected prior and new values. |
| FR-10 | Unauthorized, invalid-state, and inactive-library operations return errors and leave related tables unchanged. |
| FR-11 | Each successful state-changing operation creates an audit event containing actor, event type, timestamp, entity/ID, and context. UPDATE or DELETE of an audit event is rejected. |
| FR-12 | After a library becomes inactive, history remains queryable while new operational transactions for that library are rejected. |
| FR-13 | Two requests for one available copy result in at most one active loan; retrying a completed return creates no extra return or inventory increment. |

Traceability note: Every FR requirement is mapped in the TDD to tables, constraints, procedures, reports, tests, and reproducible validation evidence. The full executable definition is maintained in `database/`, and the authoritative build order is `database/manifest.txt`.

## 11. Revision history and feedback disposition

### Document revision history

| Version | Revision | Summary |
|---|---|---|
| 1.0 | Initial draft | Established the Little Free Library topic, initial scope, three functional requirements, three business rules, three reports, assumptions, and acceptance criteria. |
| 2.0 | Requirements revision | Reworked the FRD after instructor feedback and project-scope clarification. Added explicit workflows, physical-copy tracking, permissions, reporting definitions, auditability, transaction rules, and testable acceptance criteria. |
| 2.1 | Feedback traceability revision | Added this revision history and documented which feedback was adopted, adapted, or not adopted, including the reason for each decision. No business behavior changed from version 2.0. |

### Feedback disposition

This table follows the section headings and recommendations in the instructor feedback document. `Adopted` means the recommendation was added substantially as proposed. `Adapted` means the concern was addressed with a project-specific implementation. `Not adopted` identifies a proposed permission or feature that the feedback made conditional and that was excluded for a stated reason.

| Feedback topic | Disposition | Revision and rationale |
|---|---|---|
| Clarify the operating model | Adopted | Sections 3, 5, 7, and 9 now identify who records checkout and return activity, require registered and attributable actors, define return behavior, allow a participating return location, distinguish recorded from observed inventory, and provide audited reconciliation. These revisions remove ambiguity about how an honor-system library produces reliable database records. |
| Turn roles into entitlements | Adapted | Section 4 adds a permission matrix for patrons, donors, and directors; supports multiple business roles and multiple director-library assignments; and limits director actions to assigned libraries. Business roles are enforced through schema relationships and controlled operations, with representative MySQL privileges documented in the TDD. |
| Director access to another patron's contact details | Not adopted | The proposed permission was conditional on explicit justification. No retained requirement needs directors to retrieve another patron's contact details, so that access was excluded to keep private data outside operational reports. |
| Expand and rewrite the functional requirements | Adopted | The three broad original requirements were replaced by thirteen numbered, testable requirements covering every retained capability: copy registration, catalog access, circulation, donations, visits, private history, demand reporting, reconciliation, authorization, audit evidence, library status, and retry safety. This supports direct traceability to design and tests. |
| Distinguish book titles from physical copies | Adopted | The model separates shared `BookTitle` data from individual `BookCopy` records so copies of one title can have different locations and states. Price was removed because the project performs no valuation or sales; quantity is derived from copy rows; visits are recorded explicitly; and library-to-book collections are modeled as relationships. |
| Define workflows and business-rule enforcement | Adopted | Checkout, return, donation, and reconciliation now specify actors, preconditions, state changes, rejection behavior, and audit results. Availability is enforced by transactional procedure logic rather than foreign keys alone. A locking read and unique active-copy key address simultaneous checkout requests, and failed operations roll back without partial changes. |
| Make reports precise enough to drive queries and indexes | Adopted | Section 8 defines the purpose, inputs, output columns, filters, aggregation, and ordering for each report. Demand uses a required date window and a defined distinct-patron measure, with checkout count retained as supporting context. These definitions are specific enough to implement and verify in SQL. |
| Replace the acceptance criteria with observable tests | Adopted | Section 10 replaces map rendering, cryptographic/dataflow language, and catalog-based ACID claims with setup/action/outcome tests for availability, concurrent checkout, return, unauthorized history access, known report fixtures, rollback, retries, reconciliation, and immutable audit evidence. The tests now measure the requirements they claim to validate. |
| Add auditability and resiliency requirements | Adapted | Successful state-changing operations require attributable, append-only audit evidence; transactions roll back incomplete work; repeated requests are rejected safely; inventory drift is corrected through recorded reconciliation; and the build initializes synthetic data reproducibly. Failed-attempt logging is kept separate from successful business-event history, as the feedback recommends. |
| Clean up inconsistent assumptions and terminology | Adopted | The unrelated supplier assumption was removed; `Reader` and `Customer` were standardized to `Patron`; demonstration identities and contact values are explicitly synthetic; library status is defined as operational `ACTIVE` or `INACTIVE`; and generic report labels were replaced by concrete results. |
