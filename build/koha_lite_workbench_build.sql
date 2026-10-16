-- KOHA-Lite Workbench build generated from database/manifest.txt
-- Safe behavior: CREATE DATABASE fails if koha_lite already exists.
-- No existing schema is dropped or replaced by this script.
SET sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
CREATE DATABASE koha_lite CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE koha_lite;

-- ============================================================================
-- BEGIN database/00_create_database.sql
-- ============================================================================
-- The build script creates and selects the target database before this file runs.
ALTER DATABASE CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
-- END database/00_create_database.sql

-- ============================================================================
-- BEGIN database/01_schema/010_reference_tables.sql
-- ============================================================================
CREATE TABLE BusinessRole (
    RoleCode VARCHAR(20) PRIMARY KEY,
    RoleName VARCHAR(60) NOT NULL UNIQUE,
    RoleDescription VARCHAR(255) NOT NULL
) ENGINE = InnoDB;

CREATE TABLE BookCategory (
    CategoryID SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    CategoryName VARCHAR(80) NOT NULL UNIQUE,
    CategoryDescription VARCHAR(255) NULL
) ENGINE = InnoDB;
-- END database/01_schema/010_reference_tables.sql

-- ============================================================================
-- BEGIN database/01_schema/020_core_tables.sql
-- ============================================================================
CREATE TABLE UserAccount (
    UserID BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    DisplayName VARCHAR(120) NOT NULL,
    Email VARCHAR(255) NOT NULL UNIQUE,
    IsActive BOOLEAN NOT NULL DEFAULT TRUE,
    CreatedAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT chk_user_display_name CHECK (CHAR_LENGTH(TRIM(DisplayName)) > 0),
    CONSTRAINT chk_user_email CHECK (Email LIKE '%_@_%._%')
) ENGINE = InnoDB;

CREATE TABLE Library (
    LibraryID BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    LibraryName VARCHAR(150) NOT NULL UNIQUE,
    AddressLine1 VARCHAR(150) NOT NULL,
    City VARCHAR(100) NOT NULL,
    StateCode CHAR(2) NOT NULL DEFAULT 'NJ',
    PostalCode VARCHAR(10) NOT NULL,
    LibraryStatus ENUM('ACTIVE', 'INACTIVE') NOT NULL DEFAULT 'ACTIVE',
    CreatedAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT chk_library_name CHECK (CHAR_LENGTH(TRIM(LibraryName)) > 0),
    CONSTRAINT chk_library_state CHECK (StateCode = 'NJ')
) ENGINE = InnoDB;

CREATE TABLE BookTitle (
    BookTitleID BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ISBN13 CHAR(13) NULL UNIQUE,
    Title VARCHAR(255) NOT NULL,
    AuthorName VARCHAR(180) NOT NULL,
    CategoryID SMALLINT UNSIGNED NOT NULL,
    CreatedAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_book_title_category
        FOREIGN KEY (CategoryID) REFERENCES BookCategory(CategoryID),
    CONSTRAINT chk_book_title CHECK (CHAR_LENGTH(TRIM(Title)) > 0),
    CONSTRAINT chk_book_author CHECK (CHAR_LENGTH(TRIM(AuthorName)) > 0),
    CONSTRAINT chk_book_isbn CHECK (ISBN13 IS NULL OR ISBN13 REGEXP '^[0-9]{13}$')
) ENGINE = InnoDB;
-- END database/01_schema/020_core_tables.sql

-- ============================================================================
-- BEGIN database/01_schema/030_relationship_tables.sql
-- ============================================================================
CREATE TABLE UserRole (
    UserID BIGINT UNSIGNED NOT NULL,
    RoleCode VARCHAR(20) NOT NULL,
    AssignedAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (UserID, RoleCode),
    CONSTRAINT fk_user_role_user
        FOREIGN KEY (UserID) REFERENCES UserAccount(UserID),
    CONSTRAINT fk_user_role_role
        FOREIGN KEY (RoleCode) REFERENCES BusinessRole(RoleCode)
) ENGINE = InnoDB;

CREATE TABLE DirectorLibrary (
    UserID BIGINT UNSIGNED NOT NULL,
    LibraryID BIGINT UNSIGNED NOT NULL,
    AssignedAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (UserID, LibraryID),
    CONSTRAINT fk_director_library_user
        FOREIGN KEY (UserID) REFERENCES UserAccount(UserID),
    CONSTRAINT fk_director_library_library
        FOREIGN KEY (LibraryID) REFERENCES Library(LibraryID)
) ENGINE = InnoDB;

CREATE TABLE Donation (
    DonationID BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    DonorUserID BIGINT UNSIGNED NOT NULL,
    ReceivingLibraryID BIGINT UNSIGNED NOT NULL,
    DonationStatus ENUM('SUBMITTED', 'ACCEPTED', 'REJECTED') NOT NULL DEFAULT 'SUBMITTED',
    SubmittedAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    DecidedAt DATETIME(6) NULL,
    DecidedByUserID BIGINT UNSIGNED NULL,
    DecisionNote VARCHAR(500) NULL,
    CONSTRAINT fk_donation_donor
        FOREIGN KEY (DonorUserID) REFERENCES UserAccount(UserID),
    CONSTRAINT fk_donation_library
        FOREIGN KEY (ReceivingLibraryID) REFERENCES Library(LibraryID),
    CONSTRAINT fk_donation_decider
        FOREIGN KEY (DecidedByUserID) REFERENCES UserAccount(UserID),
    CONSTRAINT chk_donation_decision CHECK (
        (DonationStatus = 'SUBMITTED' AND DecidedAt IS NULL AND DecidedByUserID IS NULL)
        OR
        (DonationStatus IN ('ACCEPTED', 'REJECTED') AND DecidedAt IS NOT NULL AND DecidedByUserID IS NOT NULL)
    )
) ENGINE = InnoDB;

CREATE TABLE DonationItem (
    DonationItemID BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    DonationID BIGINT UNSIGNED NOT NULL,
    BookTitleID BIGINT UNSIGNED NOT NULL,
    OfferedQuantity SMALLINT UNSIGNED NOT NULL,
    AcceptedQuantity SMALLINT UNSIGNED NULL,
    CONSTRAINT fk_donation_item_donation
        FOREIGN KEY (DonationID) REFERENCES Donation(DonationID),
    CONSTRAINT fk_donation_item_title
        FOREIGN KEY (BookTitleID) REFERENCES BookTitle(BookTitleID),
    CONSTRAINT uq_donation_item_title UNIQUE (DonationID, BookTitleID),
    CONSTRAINT chk_donation_offered_quantity CHECK (OfferedQuantity > 0),
    CONSTRAINT chk_donation_accepted_quantity CHECK (
        AcceptedQuantity IS NULL OR AcceptedQuantity <= OfferedQuantity
    )
) ENGINE = InnoDB;

CREATE TABLE BookCopy (
    BookCopyID BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    BookTitleID BIGINT UNSIGNED NOT NULL,
    CurrentLibraryID BIGINT UNSIGNED NULL,
    CopyStatus ENUM('AVAILABLE', 'ON_LOAN', 'LOST', 'RETIRED') NOT NULL DEFAULT 'AVAILABLE',
    RegistrationSource ENUM('DIRECT', 'DONATION') NOT NULL,
    DonationItemID BIGINT UNSIGNED NULL,
    RegisteredByUserID BIGINT UNSIGNED NOT NULL,
    RegisteredAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_book_copy_title
        FOREIGN KEY (BookTitleID) REFERENCES BookTitle(BookTitleID),
    CONSTRAINT fk_book_copy_library
        FOREIGN KEY (CurrentLibraryID) REFERENCES Library(LibraryID),
    CONSTRAINT fk_book_copy_donation_item
        FOREIGN KEY (DonationItemID) REFERENCES DonationItem(DonationItemID),
    CONSTRAINT fk_book_copy_registered_by
        FOREIGN KEY (RegisteredByUserID) REFERENCES UserAccount(UserID),
    CONSTRAINT chk_book_copy_location CHECK (
        (CopyStatus IN ('AVAILABLE', 'ON_LOAN') AND CurrentLibraryID IS NOT NULL)
        OR CopyStatus IN ('LOST', 'RETIRED')
    ),
    CONSTRAINT chk_book_copy_source CHECK (
        (RegistrationSource = 'DIRECT' AND DonationItemID IS NULL)
        OR (RegistrationSource = 'DONATION' AND DonationItemID IS NOT NULL)
    )
) ENGINE = InnoDB;

CREATE TABLE Loan (
    LoanID BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    BookCopyID BIGINT UNSIGNED NOT NULL,
    PatronUserID BIGINT UNSIGNED NOT NULL,
    CheckoutLibraryID BIGINT UNSIGNED NOT NULL,
    CheckoutRecordedByUserID BIGINT UNSIGNED NOT NULL,
    CheckoutAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    ReturnLibraryID BIGINT UNSIGNED NULL,
    ReturnRecordedByUserID BIGINT UNSIGNED NULL,
    ReturnedAt DATETIME(6) NULL,
    LoanStatus ENUM('ACTIVE', 'RETURNED') NOT NULL DEFAULT 'ACTIVE',
    ActiveBookCopyID BIGINT UNSIGNED GENERATED ALWAYS AS (
        CASE WHEN LoanStatus = 'ACTIVE' THEN BookCopyID ELSE NULL END
    ) STORED,
    CONSTRAINT fk_loan_copy
        FOREIGN KEY (BookCopyID) REFERENCES BookCopy(BookCopyID),
    CONSTRAINT fk_loan_patron
        FOREIGN KEY (PatronUserID) REFERENCES UserAccount(UserID),
    CONSTRAINT fk_loan_checkout_library
        FOREIGN KEY (CheckoutLibraryID) REFERENCES Library(LibraryID),
    CONSTRAINT fk_loan_checkout_actor
        FOREIGN KEY (CheckoutRecordedByUserID) REFERENCES UserAccount(UserID),
    CONSTRAINT fk_loan_return_library
        FOREIGN KEY (ReturnLibraryID) REFERENCES Library(LibraryID),
    CONSTRAINT fk_loan_return_actor
        FOREIGN KEY (ReturnRecordedByUserID) REFERENCES UserAccount(UserID),
    CONSTRAINT uq_loan_active_copy UNIQUE (ActiveBookCopyID),
    CONSTRAINT chk_loan_return_state CHECK (
        (LoanStatus = 'ACTIVE' AND ReturnLibraryID IS NULL AND ReturnRecordedByUserID IS NULL AND ReturnedAt IS NULL)
        OR
        (LoanStatus = 'RETURNED' AND ReturnLibraryID IS NOT NULL AND ReturnRecordedByUserID IS NOT NULL AND ReturnedAt IS NOT NULL)
    ),
    CONSTRAINT chk_loan_time CHECK (ReturnedAt IS NULL OR ReturnedAt >= CheckoutAt)
) ENGINE = InnoDB;

CREATE TABLE Visit (
    VisitID BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    PatronUserID BIGINT UNSIGNED NOT NULL,
    LibraryID BIGINT UNSIGNED NOT NULL,
    VisitedAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    RecordedByUserID BIGINT UNSIGNED NOT NULL,
    RecordingMethod ENUM('PATRON_SELF', 'DIRECTOR') NOT NULL,
    CONSTRAINT fk_visit_patron
        FOREIGN KEY (PatronUserID) REFERENCES UserAccount(UserID),
    CONSTRAINT fk_visit_library
        FOREIGN KEY (LibraryID) REFERENCES Library(LibraryID),
    CONSTRAINT fk_visit_actor
        FOREIGN KEY (RecordedByUserID) REFERENCES UserAccount(UserID)
) ENGINE = InnoDB;

CREATE TABLE InventoryAdjustment (
    AdjustmentID BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    BookCopyID BIGINT UNSIGNED NOT NULL,
    DirectorUserID BIGINT UNSIGNED NOT NULL,
    PreviousLibraryID BIGINT UNSIGNED NULL,
    NewLibraryID BIGINT UNSIGNED NULL,
    PreviousStatus ENUM('AVAILABLE', 'ON_LOAN', 'LOST', 'RETIRED') NOT NULL,
    NewStatus ENUM('AVAILABLE', 'ON_LOAN', 'LOST', 'RETIRED') NOT NULL,
    Reason VARCHAR(500) NOT NULL,
    AdjustedAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_adjustment_copy
        FOREIGN KEY (BookCopyID) REFERENCES BookCopy(BookCopyID),
    CONSTRAINT fk_adjustment_director
        FOREIGN KEY (DirectorUserID) REFERENCES UserAccount(UserID),
    CONSTRAINT fk_adjustment_previous_library
        FOREIGN KEY (PreviousLibraryID) REFERENCES Library(LibraryID),
    CONSTRAINT fk_adjustment_new_library
        FOREIGN KEY (NewLibraryID) REFERENCES Library(LibraryID),
    CONSTRAINT chk_adjustment_reason CHECK (CHAR_LENGTH(TRIM(Reason)) >= 5),
    CONSTRAINT chk_adjustment_changed CHECK (
        NOT (PreviousStatus <=> NewStatus) OR NOT (PreviousLibraryID <=> NewLibraryID)
    )
) ENGINE = InnoDB;

CREATE TABLE AuditEvent (
    AuditEventID BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ActorUserID BIGINT UNSIGNED NOT NULL,
    EventType VARCHAR(60) NOT NULL,
    EntityType VARCHAR(60) NOT NULL,
    EntityID BIGINT UNSIGNED NOT NULL,
    EventTimestamp DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    Outcome ENUM('SUCCEEDED', 'REJECTED') NOT NULL DEFAULT 'SUCCEEDED',
    LibraryID BIGINT UNSIGNED NULL,
    ContextData JSON NULL,
    CONSTRAINT fk_audit_actor
        FOREIGN KEY (ActorUserID) REFERENCES UserAccount(UserID),
    CONSTRAINT fk_audit_library
        FOREIGN KEY (LibraryID) REFERENCES Library(LibraryID),
    CONSTRAINT chk_audit_event_type CHECK (CHAR_LENGTH(TRIM(EventType)) > 0),
    CONSTRAINT chk_audit_entity_type CHECK (CHAR_LENGTH(TRIM(EntityType)) > 0)
) ENGINE = InnoDB;
-- END database/01_schema/030_relationship_tables.sql

-- ============================================================================
-- BEGIN database/01_schema/040_constraints.sql
-- ============================================================================
CREATE INDEX idx_book_title_category_title
    ON BookTitle (CategoryID, Title);

CREATE INDEX idx_book_copy_library_status_title
    ON BookCopy (CurrentLibraryID, CopyStatus, BookTitleID);

CREATE INDEX idx_loan_patron_checkout
    ON Loan (PatronUserID, CheckoutAt DESC);

CREATE INDEX idx_loan_library_checkout
    ON Loan (CheckoutLibraryID, CheckoutAt DESC);

CREATE INDEX idx_loan_copy_history
    ON Loan (BookCopyID, CheckoutAt DESC);

CREATE INDEX idx_visit_patron_time
    ON Visit (PatronUserID, VisitedAt DESC);

CREATE INDEX idx_visit_library_time
    ON Visit (LibraryID, VisitedAt DESC);

CREATE INDEX idx_donation_donor_status
    ON Donation (DonorUserID, DonationStatus, SubmittedAt DESC);

CREATE INDEX idx_donation_library_status
    ON Donation (ReceivingLibraryID, DonationStatus, SubmittedAt DESC);

CREATE INDEX idx_adjustment_copy_time
    ON InventoryAdjustment (BookCopyID, AdjustedAt DESC);

CREATE INDEX idx_audit_entity_time
    ON AuditEvent (EntityType, EntityID, EventTimestamp DESC);

CREATE INDEX idx_audit_library_time
    ON AuditEvent (LibraryID, EventTimestamp DESC);
-- END database/01_schema/040_constraints.sql

-- ============================================================================
-- BEGIN database/02_programmability/010_views.sql
-- ============================================================================
CREATE VIEW vw_AvailableCatalog AS
SELECT
    l.LibraryID,
    l.LibraryName,
    bt.BookTitleID,
    bt.Title,
    bt.AuthorName,
    bc.CategoryID,
    bc.CategoryName,
    COUNT(*) AS AvailableCopyCount
FROM Library AS l
JOIN BookCopy AS cp
    ON cp.CurrentLibraryID = l.LibraryID
   AND cp.CopyStatus = 'AVAILABLE'
JOIN BookTitle AS bt
    ON bt.BookTitleID = cp.BookTitleID
JOIN BookCategory AS bc
    ON bc.CategoryID = bt.CategoryID
WHERE l.LibraryStatus = 'ACTIVE'
GROUP BY
    l.LibraryID, l.LibraryName,
    bt.BookTitleID, bt.Title, bt.AuthorName,
    bc.CategoryID, bc.CategoryName;

CREATE VIEW vw_ActiveLoan AS
SELECT
    ln.LoanID,
    ln.BookCopyID,
    bt.BookTitleID,
    bt.Title,
    ln.PatronUserID,
    p.DisplayName AS PatronName,
    ln.CheckoutLibraryID,
    l.LibraryName AS CheckoutLibraryName,
    ln.CheckoutAt,
    ln.CheckoutRecordedByUserID
FROM Loan AS ln
JOIN BookCopy AS cp ON cp.BookCopyID = ln.BookCopyID
JOIN BookTitle AS bt ON bt.BookTitleID = cp.BookTitleID
JOIN UserAccount AS p ON p.UserID = ln.PatronUserID
JOIN Library AS l ON l.LibraryID = ln.CheckoutLibraryID
WHERE ln.LoanStatus = 'ACTIVE';

CREATE VIEW vw_LoanHistory AS
SELECT
    ln.LoanID,
    ln.PatronUserID,
    ln.BookCopyID,
    bt.BookTitleID,
    bt.Title,
    ln.CheckoutAt,
    ln.ReturnedAt,
    ln.LoanStatus,
    ln.CheckoutLibraryID,
    checkout_library.LibraryName AS CheckoutLibraryName,
    ln.ReturnLibraryID,
    return_library.LibraryName AS ReturnLibraryName
FROM Loan AS ln
JOIN BookCopy AS cp ON cp.BookCopyID = ln.BookCopyID
JOIN BookTitle AS bt ON bt.BookTitleID = cp.BookTitleID
JOIN Library AS checkout_library ON checkout_library.LibraryID = ln.CheckoutLibraryID
LEFT JOIN Library AS return_library ON return_library.LibraryID = ln.ReturnLibraryID;

CREATE VIEW vw_Inventory AS
SELECT
    cp.BookCopyID,
    cp.BookTitleID,
    bt.Title,
    bt.AuthorName,
    cp.CurrentLibraryID,
    l.LibraryName,
    cp.CopyStatus,
    cp.RegistrationSource,
    cp.RegisteredAt,
    CASE WHEN al.LoanID IS NULL THEN 0 ELSE 1 END AS HasActiveLoan
FROM BookCopy AS cp
JOIN BookTitle AS bt ON bt.BookTitleID = cp.BookTitleID
LEFT JOIN Library AS l ON l.LibraryID = cp.CurrentLibraryID
LEFT JOIN Loan AS al
    ON al.BookCopyID = cp.BookCopyID
   AND al.LoanStatus = 'ACTIVE';

CREATE VIEW vw_DonationStatus AS
SELECT
    d.DonationID,
    d.DonorUserID,
    donor.DisplayName AS DonorName,
    d.ReceivingLibraryID,
    l.LibraryName,
    d.DonationStatus,
    d.SubmittedAt,
    d.DecidedAt,
    d.DecidedByUserID,
    COUNT(di.DonationItemID) AS DistinctTitleCount,
    COALESCE(SUM(di.OfferedQuantity), 0) AS OfferedCopyCount,
    COALESCE(SUM(di.AcceptedQuantity), 0) AS AcceptedCopyCount
FROM Donation AS d
JOIN UserAccount AS donor ON donor.UserID = d.DonorUserID
JOIN Library AS l ON l.LibraryID = d.ReceivingLibraryID
LEFT JOIN DonationItem AS di ON di.DonationID = d.DonationID
GROUP BY
    d.DonationID, d.DonorUserID, donor.DisplayName,
    d.ReceivingLibraryID, l.LibraryName,
    d.DonationStatus, d.SubmittedAt, d.DecidedAt, d.DecidedByUserID;

CREATE VIEW vw_AuditHistory AS
SELECT
    ae.AuditEventID,
    ae.ActorUserID,
    actor.DisplayName AS ActorName,
    ae.EventType,
    ae.EntityType,
    ae.EntityID,
    ae.EventTimestamp,
    ae.Outcome,
    ae.LibraryID,
    l.LibraryName,
    ae.ContextData
FROM AuditEvent AS ae
JOIN UserAccount AS actor ON actor.UserID = ae.ActorUserID
LEFT JOIN Library AS l ON l.LibraryID = ae.LibraryID;
-- END database/02_programmability/010_views.sql

-- ============================================================================
-- BEGIN database/02_programmability/020_functions.sql
-- ============================================================================
DELIMITER //

CREATE FUNCTION fn_HasRole (
    p_UserID BIGINT UNSIGNED,
    p_RoleCode VARCHAR(20)
)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM UserAccount AS u
        JOIN UserRole AS ur ON ur.UserID = u.UserID
        WHERE u.UserID = p_UserID
          AND u.IsActive = TRUE
          AND ur.RoleCode = p_RoleCode
    );
END//

CREATE FUNCTION fn_DirectorManagesLibrary (
    p_UserID BIGINT UNSIGNED,
    p_LibraryID BIGINT UNSIGNED
)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    RETURN fn_HasRole(p_UserID, 'DIRECTOR')
       AND EXISTS (
            SELECT 1
            FROM DirectorLibrary
            WHERE UserID = p_UserID
              AND LibraryID = p_LibraryID
       );
END//

DELIMITER ;
-- END database/02_programmability/020_functions.sql

-- ============================================================================
-- BEGIN database/02_programmability/030_procedures.sql
-- ============================================================================
DELIMITER //

CREATE PROCEDURE sp_RegisterBookCopy (
    IN p_ActorUserID BIGINT UNSIGNED,
    IN p_LibraryID BIGINT UNSIGNED,
    IN p_BookTitleID BIGINT UNSIGNED,
    OUT p_BookCopyID BIGINT UNSIGNED
)
BEGIN
    DECLARE v_LibraryActive BOOLEAN DEFAULT FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT fn_DirectorManagesLibrary(p_ActorUserID, p_LibraryID) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Director is not authorized for this library.';
    END IF;

    SELECT LibraryStatus = 'ACTIVE' INTO v_LibraryActive
    FROM Library WHERE LibraryID = p_LibraryID;
    IF COALESCE(v_LibraryActive, FALSE) = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Library is not active.';
    END IF;

    START TRANSACTION;
    INSERT INTO BookCopy
        (BookTitleID, CurrentLibraryID, CopyStatus, RegistrationSource, RegisteredByUserID)
    VALUES
        (p_BookTitleID, p_LibraryID, 'AVAILABLE', 'DIRECT', p_ActorUserID);
    SET p_BookCopyID = LAST_INSERT_ID();

    INSERT INTO AuditEvent
        (ActorUserID, EventType, EntityType, EntityID, LibraryID, ContextData)
    VALUES
        (p_ActorUserID, 'BOOK_COPY_REGISTERED', 'BookCopy', p_BookCopyID, p_LibraryID,
         JSON_OBJECT('bookTitleId', p_BookTitleID, 'source', 'DIRECT'));
    COMMIT;
END//

CREATE PROCEDURE sp_CheckoutCopy (
    IN p_ActorUserID BIGINT UNSIGNED,
    IN p_PatronUserID BIGINT UNSIGNED,
    IN p_BookCopyID BIGINT UNSIGNED,
    IN p_LibraryID BIGINT UNSIGNED,
    IN p_CheckoutAt DATETIME(6),
    OUT p_LoanID BIGINT UNSIGNED
)
BEGIN
    DECLARE v_CopyStatus VARCHAR(20);
    DECLARE v_CurrentLibraryID BIGINT UNSIGNED;
    DECLARE v_LibraryStatus VARCHAR(20);
    DECLARE v_Found BOOLEAN DEFAULT TRUE;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_Found = FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT fn_HasRole(p_PatronUserID, 'PATRON') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Borrower is not an active registered patron.';
    END IF;
    IF p_ActorUserID <> p_PatronUserID
       AND NOT fn_DirectorManagesLibrary(p_ActorUserID, p_LibraryID) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Actor may not record this checkout.';
    END IF;
    IF p_ActorUserID = p_PatronUserID
       AND NOT fn_HasRole(p_ActorUserID, 'PATRON') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Actor is not an active patron.';
    END IF;

    START TRANSACTION;
    SET v_Found = TRUE;
    SELECT cp.CopyStatus, cp.CurrentLibraryID, l.LibraryStatus
      INTO v_CopyStatus, v_CurrentLibraryID, v_LibraryStatus
    FROM BookCopy AS cp
    JOIN Library AS l ON l.LibraryID = cp.CurrentLibraryID
    WHERE cp.BookCopyID = p_BookCopyID
    FOR UPDATE;

    IF NOT v_Found THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Book copy does not exist.';
    END IF;
    IF v_CurrentLibraryID <> p_LibraryID OR v_LibraryStatus <> 'ACTIVE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Copy is not at the selected active library.';
    END IF;
    IF v_CopyStatus <> 'AVAILABLE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Copy is not available.';
    END IF;

    INSERT INTO Loan
        (BookCopyID, PatronUserID, CheckoutLibraryID, CheckoutRecordedByUserID, CheckoutAt)
    VALUES
        (p_BookCopyID, p_PatronUserID, p_LibraryID, p_ActorUserID,
         COALESCE(p_CheckoutAt, CURRENT_TIMESTAMP(6)));
    SET p_LoanID = LAST_INSERT_ID();

    UPDATE BookCopy
    SET CopyStatus = 'ON_LOAN'
    WHERE BookCopyID = p_BookCopyID;

    INSERT INTO AuditEvent
        (ActorUserID, EventType, EntityType, EntityID, LibraryID, ContextData)
    VALUES
        (p_ActorUserID, 'COPY_CHECKED_OUT', 'Loan', p_LoanID, p_LibraryID,
         JSON_OBJECT('bookCopyId', p_BookCopyID, 'patronUserId', p_PatronUserID));
    COMMIT;
END//

CREATE PROCEDURE sp_ReturnCopy (
    IN p_ActorUserID BIGINT UNSIGNED,
    IN p_LoanID BIGINT UNSIGNED,
    IN p_ReturnLibraryID BIGINT UNSIGNED,
    IN p_ReturnedAt DATETIME(6)
)
BEGIN
    DECLARE v_PatronUserID BIGINT UNSIGNED;
    DECLARE v_BookCopyID BIGINT UNSIGNED;
    DECLARE v_LoanStatus VARCHAR(20);
    DECLARE v_LibraryStatus VARCHAR(20);
    DECLARE v_Found BOOLEAN DEFAULT TRUE;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_Found = FALSE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT LibraryStatus INTO v_LibraryStatus
    FROM Library WHERE LibraryID = p_ReturnLibraryID;
    IF v_LibraryStatus IS NULL OR v_LibraryStatus <> 'ACTIVE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Return library is not active.';
    END IF;

    START TRANSACTION;
    SET v_Found = TRUE;
    SELECT PatronUserID, BookCopyID, LoanStatus
      INTO v_PatronUserID, v_BookCopyID, v_LoanStatus
    FROM Loan
    WHERE LoanID = p_LoanID
    FOR UPDATE;

    IF NOT v_Found THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Loan does not exist.';
    END IF;
    IF p_ActorUserID <> v_PatronUserID
       AND NOT fn_DirectorManagesLibrary(p_ActorUserID, p_ReturnLibraryID) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Actor may not record this return.';
    END IF;
    IF v_LoanStatus <> 'ACTIVE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Loan is not active; duplicate return rejected.';
    END IF;

    UPDATE Loan
    SET ReturnLibraryID = p_ReturnLibraryID,
        ReturnRecordedByUserID = p_ActorUserID,
        ReturnedAt = COALESCE(p_ReturnedAt, CURRENT_TIMESTAMP(6)),
        LoanStatus = 'RETURNED'
    WHERE LoanID = p_LoanID;

    UPDATE BookCopy
    SET CurrentLibraryID = p_ReturnLibraryID,
        CopyStatus = 'AVAILABLE'
    WHERE BookCopyID = v_BookCopyID;

    INSERT INTO AuditEvent
        (ActorUserID, EventType, EntityType, EntityID, LibraryID, ContextData)
    VALUES
        (p_ActorUserID, 'COPY_RETURNED', 'Loan', p_LoanID, p_ReturnLibraryID,
         JSON_OBJECT('bookCopyId', v_BookCopyID, 'patronUserId', v_PatronUserID));
    COMMIT;
END//

CREATE PROCEDURE sp_RecordVisit (
    IN p_ActorUserID BIGINT UNSIGNED,
    IN p_PatronUserID BIGINT UNSIGNED,
    IN p_LibraryID BIGINT UNSIGNED,
    IN p_VisitedAt DATETIME(6),
    OUT p_VisitID BIGINT UNSIGNED
)
BEGIN
    DECLARE v_Method VARCHAR(20);
    DECLARE v_LibraryStatus VARCHAR(20);

    IF NOT fn_HasRole(p_PatronUserID, 'PATRON') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Visitor is not an active patron.';
    END IF;
    SELECT LibraryStatus INTO v_LibraryStatus FROM Library WHERE LibraryID = p_LibraryID;
    IF v_LibraryStatus IS NULL OR v_LibraryStatus <> 'ACTIVE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Library is not active.';
    END IF;
    IF p_ActorUserID = p_PatronUserID THEN
        SET v_Method = 'PATRON_SELF';
    ELSEIF fn_DirectorManagesLibrary(p_ActorUserID, p_LibraryID) THEN
        SET v_Method = 'DIRECTOR';
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Actor may not record this visit.';
    END IF;

    START TRANSACTION;
    INSERT INTO Visit
        (PatronUserID, LibraryID, VisitedAt, RecordedByUserID, RecordingMethod)
    VALUES
        (p_PatronUserID, p_LibraryID, COALESCE(p_VisitedAt, CURRENT_TIMESTAMP(6)),
         p_ActorUserID, v_Method);
    SET p_VisitID = LAST_INSERT_ID();
    INSERT INTO AuditEvent
        (ActorUserID, EventType, EntityType, EntityID, LibraryID, ContextData)
    VALUES
        (p_ActorUserID, 'VISIT_RECORDED', 'Visit', p_VisitID, p_LibraryID,
         JSON_OBJECT('patronUserId', p_PatronUserID, 'recordingMethod', v_Method));
    COMMIT;
END//

CREATE PROCEDURE sp_SubmitDonation (
    IN p_ActorUserID BIGINT UNSIGNED,
    IN p_ReceivingLibraryID BIGINT UNSIGNED,
    IN p_BookTitleID BIGINT UNSIGNED,
    IN p_OfferedQuantity SMALLINT UNSIGNED,
    OUT p_DonationID BIGINT UNSIGNED
)
BEGIN
    DECLARE v_LibraryStatus VARCHAR(20);
    IF NOT EXISTS (SELECT 1 FROM UserAccount WHERE UserID = p_ActorUserID AND IsActive = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Donor is not an active registered user.';
    END IF;
    IF p_OfferedQuantity IS NULL OR p_OfferedQuantity = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Offered quantity must be positive.';
    END IF;
    SELECT LibraryStatus INTO v_LibraryStatus FROM Library WHERE LibraryID = p_ReceivingLibraryID;
    IF v_LibraryStatus IS NULL OR v_LibraryStatus <> 'ACTIVE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Receiving library is not active.';
    END IF;

    START TRANSACTION;
    INSERT INTO Donation (DonorUserID, ReceivingLibraryID)
    VALUES (p_ActorUserID, p_ReceivingLibraryID);
    SET p_DonationID = LAST_INSERT_ID();
    INSERT INTO DonationItem (DonationID, BookTitleID, OfferedQuantity)
    VALUES (p_DonationID, p_BookTitleID, p_OfferedQuantity);
    INSERT INTO AuditEvent
        (ActorUserID, EventType, EntityType, EntityID, LibraryID, ContextData)
    VALUES
        (p_ActorUserID, 'DONATION_SUBMITTED', 'Donation', p_DonationID, p_ReceivingLibraryID,
         JSON_OBJECT('bookTitleId', p_BookTitleID, 'offeredQuantity', p_OfferedQuantity));
    COMMIT;
END//

CREATE PROCEDURE sp_AcceptDonation (
    IN p_DirectorUserID BIGINT UNSIGNED,
    IN p_DonationID BIGINT UNSIGNED,
    IN p_DecisionNote VARCHAR(500)
)
BEGIN
    DECLARE v_LibraryID BIGINT UNSIGNED;
    DECLARE v_Status VARCHAR(20);
    DECLARE v_Done BOOLEAN DEFAULT FALSE;
    DECLARE v_ItemID BIGINT UNSIGNED;
    DECLARE v_TitleID BIGINT UNSIGNED;
    DECLARE v_Quantity SMALLINT UNSIGNED;
    DECLARE v_Counter SMALLINT UNSIGNED;
    DECLARE item_cursor CURSOR FOR
        SELECT DonationItemID, BookTitleID, OfferedQuantity
        FROM DonationItem WHERE DonationID = p_DonationID;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_Done = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SELECT ReceivingLibraryID, DonationStatus
      INTO v_LibraryID, v_Status
    FROM Donation WHERE DonationID = p_DonationID;
    IF v_LibraryID IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Donation does not exist.';
    END IF;
    IF v_Status <> 'SUBMITTED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Donation has already been decided.';
    END IF;
    IF NOT fn_DirectorManagesLibrary(p_DirectorUserID, v_LibraryID) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Director is not authorized for the receiving library.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM Library WHERE LibraryID = v_LibraryID AND LibraryStatus = 'ACTIVE') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Receiving library is not active.';
    END IF;

    START TRANSACTION;
    UPDATE Donation
    SET DonationStatus = 'ACCEPTED', DecidedAt = CURRENT_TIMESTAMP(6),
        DecidedByUserID = p_DirectorUserID, DecisionNote = p_DecisionNote
    WHERE DonationID = p_DonationID;

    OPEN item_cursor;
    item_loop: LOOP
        FETCH item_cursor INTO v_ItemID, v_TitleID, v_Quantity;
        IF v_Done THEN LEAVE item_loop; END IF;
        UPDATE DonationItem SET AcceptedQuantity = v_Quantity
        WHERE DonationItemID = v_ItemID;
        SET v_Counter = 0;
        copy_loop: WHILE v_Counter < v_Quantity DO
            INSERT INTO BookCopy
                (BookTitleID, CurrentLibraryID, CopyStatus, RegistrationSource,
                 DonationItemID, RegisteredByUserID)
            VALUES
                (v_TitleID, v_LibraryID, 'AVAILABLE', 'DONATION',
                 v_ItemID, p_DirectorUserID);
            SET v_Counter = v_Counter + 1;
        END WHILE copy_loop;
    END LOOP item_loop;
    CLOSE item_cursor;

    INSERT INTO AuditEvent
        (ActorUserID, EventType, EntityType, EntityID, LibraryID, ContextData)
    VALUES
        (p_DirectorUserID, 'DONATION_ACCEPTED', 'Donation', p_DonationID, v_LibraryID,
         JSON_OBJECT('decisionNote', p_DecisionNote));
    COMMIT;
END//

CREATE PROCEDURE sp_RejectDonation (
    IN p_DirectorUserID BIGINT UNSIGNED,
    IN p_DonationID BIGINT UNSIGNED,
    IN p_DecisionNote VARCHAR(500)
)
BEGIN
    DECLARE v_LibraryID BIGINT UNSIGNED;
    DECLARE v_Status VARCHAR(20);
    SELECT ReceivingLibraryID, DonationStatus INTO v_LibraryID, v_Status
    FROM Donation WHERE DonationID = p_DonationID;
    IF v_LibraryID IS NULL OR v_Status <> 'SUBMITTED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Donation is missing or already decided.';
    END IF;
    IF NOT fn_DirectorManagesLibrary(p_DirectorUserID, v_LibraryID) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Director is not authorized for the receiving library.';
    END IF;
    START TRANSACTION;
    UPDATE Donation
    SET DonationStatus = 'REJECTED', DecidedAt = CURRENT_TIMESTAMP(6),
        DecidedByUserID = p_DirectorUserID, DecisionNote = p_DecisionNote
    WHERE DonationID = p_DonationID;
    UPDATE DonationItem SET AcceptedQuantity = 0 WHERE DonationID = p_DonationID;
    INSERT INTO AuditEvent
        (ActorUserID, EventType, EntityType, EntityID, LibraryID, ContextData)
    VALUES
        (p_DirectorUserID, 'DONATION_REJECTED', 'Donation', p_DonationID, v_LibraryID,
         JSON_OBJECT('decisionNote', p_DecisionNote));
    COMMIT;
END//

CREATE PROCEDURE sp_AdjustInventory (
    IN p_DirectorUserID BIGINT UNSIGNED,
    IN p_BookCopyID BIGINT UNSIGNED,
    IN p_NewLibraryID BIGINT UNSIGNED,
    IN p_NewStatus VARCHAR(20),
    IN p_Reason VARCHAR(500)
)
BEGIN
    DECLARE v_PreviousLibraryID BIGINT UNSIGNED;
    DECLARE v_PreviousStatus VARCHAR(20);
    DECLARE v_TargetLibraryID BIGINT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_Reason IS NULL OR CHAR_LENGTH(TRIM(p_Reason)) < 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A meaningful adjustment reason is required.';
    END IF;
    IF p_NewStatus NOT IN ('AVAILABLE', 'LOST', 'RETIRED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Inventory adjustment cannot create an on-loan state.';
    END IF;

    START TRANSACTION;
    SELECT CurrentLibraryID, CopyStatus
      INTO v_PreviousLibraryID, v_PreviousStatus
    FROM BookCopy WHERE BookCopyID = p_BookCopyID FOR UPDATE;
    SET v_TargetLibraryID = COALESCE(p_NewLibraryID, v_PreviousLibraryID);

    IF NOT fn_DirectorManagesLibrary(p_DirectorUserID, v_PreviousLibraryID)
       OR NOT fn_DirectorManagesLibrary(p_DirectorUserID, v_TargetLibraryID) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Director must manage both affected libraries.';
    END IF;
    IF v_PreviousStatus = 'ON_LOAN'
       OR EXISTS (SELECT 1 FROM Loan WHERE BookCopyID = p_BookCopyID AND LoanStatus = 'ACTIVE') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An actively loaned copy cannot be reconciled.';
    END IF;
    IF v_PreviousStatus = p_NewStatus AND (v_PreviousLibraryID <=> v_TargetLibraryID) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Adjustment must change location or status.';
    END IF;

    UPDATE BookCopy
    SET CurrentLibraryID = v_TargetLibraryID,
        CopyStatus = p_NewStatus
    WHERE BookCopyID = p_BookCopyID;

    INSERT INTO InventoryAdjustment
        (BookCopyID, DirectorUserID, PreviousLibraryID, NewLibraryID,
         PreviousStatus, NewStatus, Reason)
    VALUES
        (p_BookCopyID, p_DirectorUserID, v_PreviousLibraryID, v_TargetLibraryID,
         v_PreviousStatus, p_NewStatus, p_Reason);

    INSERT INTO AuditEvent
        (ActorUserID, EventType, EntityType, EntityID, LibraryID, ContextData)
    VALUES
        (p_DirectorUserID, 'INVENTORY_ADJUSTED', 'BookCopy', p_BookCopyID, v_TargetLibraryID,
         JSON_OBJECT('previousLibraryId', v_PreviousLibraryID,
                     'newLibraryId', v_TargetLibraryID,
                     'previousStatus', v_PreviousStatus,
                     'newStatus', p_NewStatus,
                     'reason', p_Reason));
    COMMIT;
END//

CREATE PROCEDURE sp_SetLibraryStatus (
    IN p_DirectorUserID BIGINT UNSIGNED,
    IN p_LibraryID BIGINT UNSIGNED,
    IN p_NewStatus VARCHAR(20)
)
BEGIN
    IF NOT fn_DirectorManagesLibrary(p_DirectorUserID, p_LibraryID) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Director is not authorized for this library.';
    END IF;
    IF p_NewStatus NOT IN ('ACTIVE', 'INACTIVE') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unsupported library status.';
    END IF;
    START TRANSACTION;
    UPDATE Library SET LibraryStatus = p_NewStatus WHERE LibraryID = p_LibraryID;
    INSERT INTO AuditEvent
        (ActorUserID, EventType, EntityType, EntityID, LibraryID, ContextData)
    VALUES
        (p_DirectorUserID, 'LIBRARY_STATUS_CHANGED', 'Library', p_LibraryID, p_LibraryID,
         JSON_OBJECT('newStatus', p_NewStatus));
    COMMIT;
END//

DELIMITER ;
-- END database/02_programmability/030_procedures.sql

-- ============================================================================
-- BEGIN database/02_programmability/040_triggers.sql
-- ============================================================================
DELIMITER //

CREATE TRIGGER trg_AuditEvent_NoUpdate
BEFORE UPDATE ON AuditEvent
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Audit events are append-only and cannot be updated.';
END//

CREATE TRIGGER trg_AuditEvent_NoDelete
BEFORE DELETE ON AuditEvent
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Audit events are append-only and cannot be deleted.';
END//

CREATE TRIGGER trg_InventoryAdjustment_NoUpdate
BEFORE UPDATE ON InventoryAdjustment
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Inventory adjustment history cannot be updated.';
END//

CREATE TRIGGER trg_InventoryAdjustment_NoDelete
BEFORE DELETE ON InventoryAdjustment
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Inventory adjustment history cannot be deleted.';
END//

DELIMITER ;
-- END database/02_programmability/040_triggers.sql

-- ============================================================================
-- BEGIN database/03_security/010_roles.sql
-- ============================================================================
CREATE ROLE IF NOT EXISTS
    'koha_catalog_reader',
    'koha_patron_operator',
    'koha_director_operator',
    'koha_auditor';
-- END database/03_security/010_roles.sql

-- ============================================================================
-- BEGIN database/03_security/020_grants.sql
-- ============================================================================
-- The reproducible project database name is koha_lite (documented in README.md).
-- Representative MySQL accounts may be assigned these database roles during the demo.
GRANT SELECT ON koha_lite.vw_AvailableCatalog TO 'koha_catalog_reader';

GRANT SELECT ON koha_lite.vw_AvailableCatalog TO 'koha_patron_operator';
GRANT SELECT ON koha_lite.vw_ActiveLoan TO 'koha_patron_operator';
GRANT SELECT ON koha_lite.vw_LoanHistory TO 'koha_patron_operator';
GRANT SELECT ON koha_lite.vw_DonationStatus TO 'koha_patron_operator';
GRANT EXECUTE ON PROCEDURE koha_lite.sp_CheckoutCopy TO 'koha_patron_operator';
GRANT EXECUTE ON PROCEDURE koha_lite.sp_ReturnCopy TO 'koha_patron_operator';
GRANT EXECUTE ON PROCEDURE koha_lite.sp_RecordVisit TO 'koha_patron_operator';
GRANT EXECUTE ON PROCEDURE koha_lite.sp_SubmitDonation TO 'koha_patron_operator';

GRANT SELECT ON koha_lite.vw_AvailableCatalog TO 'koha_director_operator';
GRANT SELECT ON koha_lite.vw_ActiveLoan TO 'koha_director_operator';
GRANT SELECT ON koha_lite.vw_LoanHistory TO 'koha_director_operator';
GRANT SELECT ON koha_lite.vw_Inventory TO 'koha_director_operator';
GRANT SELECT ON koha_lite.vw_DonationStatus TO 'koha_director_operator';
GRANT SELECT ON koha_lite.vw_AuditHistory TO 'koha_director_operator';
GRANT EXECUTE ON PROCEDURE koha_lite.sp_RegisterBookCopy TO 'koha_director_operator';
GRANT EXECUTE ON PROCEDURE koha_lite.sp_CheckoutCopy TO 'koha_director_operator';
GRANT EXECUTE ON PROCEDURE koha_lite.sp_ReturnCopy TO 'koha_director_operator';
GRANT EXECUTE ON PROCEDURE koha_lite.sp_RecordVisit TO 'koha_director_operator';
GRANT EXECUTE ON PROCEDURE koha_lite.sp_SubmitDonation TO 'koha_director_operator';
GRANT EXECUTE ON PROCEDURE koha_lite.sp_AcceptDonation TO 'koha_director_operator';
GRANT EXECUTE ON PROCEDURE koha_lite.sp_RejectDonation TO 'koha_director_operator';
GRANT EXECUTE ON PROCEDURE koha_lite.sp_AdjustInventory TO 'koha_director_operator';
GRANT EXECUTE ON PROCEDURE koha_lite.sp_SetLibraryStatus TO 'koha_director_operator';

GRANT SELECT ON koha_lite.vw_AuditHistory TO 'koha_auditor';
GRANT SELECT ON koha_lite.InventoryAdjustment TO 'koha_auditor';
-- END database/03_security/020_grants.sql

-- ============================================================================
-- BEGIN database/04_seed/010_reference_data.sql
-- ============================================================================
INSERT INTO BusinessRole (RoleCode, RoleName, RoleDescription) VALUES
    ('PATRON', 'Patron', 'Borrows and returns copies and records personal visits.'),
    ('DONOR', 'Donor', 'Submits donations and reviews aggregate demand.'),
    ('DIRECTOR', 'Director', 'Administers one or more assigned libraries.');

INSERT INTO BookCategory (CategoryID, CategoryName, CategoryDescription) VALUES
    (1, 'Fiction', 'Novels and short-story collections.'),
    (2, 'Nonfiction', 'General factual and instructional works.'),
    (3, 'Children', 'Books primarily intended for children.'),
    (4, 'Mystery', 'Mystery and detective fiction.'),
    (5, 'Science', 'Popular science and scientific reference works.');
-- END database/04_seed/010_reference_data.sql

-- ============================================================================
-- BEGIN database/04_seed/020_sample_data.sql
-- ============================================================================
INSERT INTO UserAccount (UserID, DisplayName, Email, IsActive) VALUES
    (1, 'Patricia Sample', 'patricia@example.test', TRUE),
    (2, 'Omar Sample', 'omar@example.test', TRUE),
    (3, 'Dana Director', 'dana@example.test', TRUE),
    (4, 'Erin Director', 'erin@example.test', TRUE),
    (5, 'Mia Donor', 'mia@example.test', TRUE),
    (6, 'Inactive Sample', 'inactive@example.test', FALSE);

INSERT INTO UserRole (UserID, RoleCode) VALUES
    (1, 'PATRON'),
    (1, 'DONOR'),
    (2, 'PATRON'),
    (3, 'DIRECTOR'),
    (4, 'DIRECTOR'),
    (5, 'DONOR'),
    (6, 'PATRON');

INSERT INTO Library
    (LibraryID, LibraryName, AddressLine1, City, StateCode, PostalCode, LibraryStatus)
VALUES
    (1, 'College Avenue Little Free Library', '100 College Avenue', 'New Brunswick', 'NJ', '08901', 'ACTIVE'),
    (2, 'Highland Park Little Free Library', '200 Raritan Avenue', 'Highland Park', 'NJ', '08904', 'ACTIVE'),
    (3, 'Piscataway Little Free Library', '300 River Road', 'Piscataway', 'NJ', '08854', 'ACTIVE');

INSERT INTO DirectorLibrary (UserID, LibraryID) VALUES
    (3, 1),
    (3, 2),
    (4, 3);

INSERT INTO BookTitle (BookTitleID, ISBN13, Title, AuthorName, CategoryID) VALUES
    (1, '9780061120084', 'To Kill a Mockingbird', 'Harper Lee', 1),
    (2, '9780141439600', 'A Tale of Two Cities', 'Charles Dickens', 1),
    (3, '9780064400558', 'Charlotte''s Web', 'E. B. White', 3),
    (4, '9780547928227', 'The Hobbit', 'J. R. R. Tolkien', 1),
    (5, '9780553380163', 'A Brief History of Time', 'Stephen Hawking', 5),
    (6, NULL, 'The Community Garden Guide', 'Alex Example', 2);

INSERT INTO BookCopy
    (BookCopyID, BookTitleID, CurrentLibraryID, CopyStatus, RegistrationSource, RegisteredByUserID)
VALUES
    (1, 1, 1, 'AVAILABLE', 'DIRECT', 3),
    (2, 1, 1, 'AVAILABLE', 'DIRECT', 3),
    (3, 1, 2, 'AVAILABLE', 'DIRECT', 3),
    (4, 2, 1, 'AVAILABLE', 'DIRECT', 3),
    (5, 3, 2, 'AVAILABLE', 'DIRECT', 3),
    (6, 4, 3, 'AVAILABLE', 'DIRECT', 4),
    (7, 5, 3, 'AVAILABLE', 'DIRECT', 4),
    (8, 6, 1, 'AVAILABLE', 'DIRECT', 3);

SET @LoanID = NULL;
CALL sp_CheckoutCopy(1, 1, 1, 1, '2026-09-01 10:00:00', @LoanID);
CALL sp_ReturnCopy(1, @LoanID, 2, '2026-09-10 12:00:00');

SET @LoanID = NULL;
CALL sp_CheckoutCopy(3, 2, 2, 1, '2026-09-02 11:00:00', @LoanID);
CALL sp_ReturnCopy(3, @LoanID, 1, '2026-09-12 14:00:00');

SET @LoanID = NULL;
CALL sp_CheckoutCopy(1, 1, 3, 2, '2026-09-15 09:30:00', @LoanID);

SET @VisitID = NULL;
CALL sp_RecordVisit(1, 1, 1, '2026-09-01 09:55:00', @VisitID);
SET @VisitID = NULL;
CALL sp_RecordVisit(3, 2, 1, '2026-09-02 10:55:00', @VisitID);

SET @DonationID = NULL;
CALL sp_SubmitDonation(5, 1, 5, 2, @DonationID);
CALL sp_AcceptDonation(3, @DonationID, 'Both copies accepted for the science collection.');
-- END database/04_seed/020_sample_data.sql

-- ============================================================================
-- BEGIN database/05_validation/010_object_validation.sql
-- ============================================================================
SELECT table_name
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = DATABASE()
ORDER BY routine_type, routine_name;

SELECT trigger_name, event_object_table, action_timing, event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = DATABASE()
ORDER BY event_object_table, trigger_name;

SELECT table_name, index_name, column_name, seq_in_index
FROM information_schema.statistics
WHERE table_schema = DATABASE()
ORDER BY table_name, index_name, seq_in_index;
-- END database/05_validation/010_object_validation.sql

-- ============================================================================
-- BEGIN database/05_validation/020_data_validation.sql
-- ============================================================================
SELECT 'UserAccount' AS EntityName, COUNT(*) AS RowCount FROM UserAccount
UNION ALL SELECT 'Library', COUNT(*) FROM Library
UNION ALL SELECT 'BookTitle', COUNT(*) FROM BookTitle
UNION ALL SELECT 'BookCopy', COUNT(*) FROM BookCopy
UNION ALL SELECT 'Loan', COUNT(*) FROM Loan
UNION ALL SELECT 'Donation', COUNT(*) FROM Donation
UNION ALL SELECT 'Visit', COUNT(*) FROM Visit
UNION ALL SELECT 'AuditEvent', COUNT(*) FROM AuditEvent;

SELECT * FROM vw_AvailableCatalog ORDER BY LibraryName, Title;
SELECT * FROM vw_ActiveLoan ORDER BY CheckoutAt;
SELECT * FROM vw_DonationStatus ORDER BY DonationID;

-- RQ-04: distinct-patron demand for a required period, optionally filtered by library.
SET @DemandStart = '2026-09-01 00:00:00';
SET @DemandEnd = '2026-10-01 00:00:00';
SET @DemandLibraryID = NULL;
SELECT
    bt.BookTitleID,
    bt.Title,
    COUNT(DISTINCT ln.PatronUserID) AS DistinctPatronCount,
    COUNT(*) AS CheckoutCount
FROM Loan AS ln
JOIN BookCopy AS cp ON cp.BookCopyID = ln.BookCopyID
JOIN BookTitle AS bt ON bt.BookTitleID = cp.BookTitleID
WHERE ln.CheckoutAt >= @DemandStart
  AND ln.CheckoutAt < @DemandEnd
  AND (@DemandLibraryID IS NULL OR ln.CheckoutLibraryID = @DemandLibraryID)
GROUP BY bt.BookTitleID, bt.Title
ORDER BY DistinctPatronCount DESC, CheckoutCount DESC, bt.Title;

EXPLAIN FORMAT=TREE
SELECT
    ln.LoanID, ln.BookCopyID, bt.Title, ln.CheckoutAt
FROM Loan AS ln
JOIN BookCopy AS cp ON cp.BookCopyID = ln.BookCopyID
JOIN BookTitle AS bt ON bt.BookTitleID = cp.BookTitleID
WHERE ln.PatronUserID = 1
  AND ln.CheckoutAt >= '2026-09-01 00:00:00'
ORDER BY ln.CheckoutAt DESC;
-- END database/05_validation/020_data_validation.sql

-- ============================================================================
-- BEGIN database/05_validation/030_smoke_tests.sql
-- ============================================================================
-- Positive assertions return PASS. Negative cases are implemented below as an
-- exception-catching test procedure so an expected rejection does not stop the build.

SELECT
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END AS ActiveLoanUniqueness,
    COUNT(*) AS ActiveLoanCount
FROM Loan
WHERE BookCopyID = 3 AND LoanStatus = 'ACTIVE';

SELECT
    CASE WHEN cp.CopyStatus = 'ON_LOAN' AND ln.LoanStatus = 'ACTIVE'
         THEN 'PASS' ELSE 'FAIL' END AS CheckoutAtomicState
FROM BookCopy AS cp
JOIN Loan AS ln ON ln.BookCopyID = cp.BookCopyID AND ln.LoanStatus = 'ACTIVE'
WHERE cp.BookCopyID = 3;

SELECT
    CASE WHEN cp.CurrentLibraryID = 2 AND ln.ReturnLibraryID = 2 AND ln.LoanStatus = 'RETURNED'
         THEN 'PASS' ELSE 'FAIL' END AS CrossLibraryReturnState
FROM BookCopy AS cp
JOIN Loan AS ln ON ln.BookCopyID = cp.BookCopyID
WHERE cp.BookCopyID = 1;

SELECT
    CASE WHEN COUNT(*) = 2 THEN 'PASS' ELSE 'FAIL' END AS DonationCreatedCopies,
    COUNT(*) AS DonatedCopyCount
FROM BookCopy AS cp
JOIN DonationItem AS di ON di.DonationItemID = cp.DonationItemID
WHERE di.DonationID = 1;

SELECT
    CASE WHEN COUNT(*) >= 7 THEN 'PASS' ELSE 'FAIL' END AS AuditCoverage,
    COUNT(*) AS AuditEventCount
FROM AuditEvent;

DELIMITER //
CREATE PROCEDURE sp_RunExpectedFailureTests()
BEGIN
    DECLARE v_Rejected BOOLEAN DEFAULT FALSE;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_Rejected = TRUE;

    SET v_Rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_Rejected = TRUE;
        SET @DuplicateLoanID = NULL;
        CALL sp_CheckoutCopy(2, 2, 3, 2, '2026-09-16 10:00:00', @DuplicateLoanID);
    END;
    SELECT CASE WHEN v_Rejected THEN 'PASS' ELSE 'FAIL' END AS UnavailableCheckoutRejected;

    SET v_Rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_Rejected = TRUE;
        CALL sp_ReturnCopy(1, 1, 1, '2026-09-20 10:00:00');
    END;
    SELECT CASE WHEN v_Rejected THEN 'PASS' ELSE 'FAIL' END AS DuplicateReturnRejected;

    SET v_Rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_Rejected = TRUE;
        SET @UnauthorizedCopyID = NULL;
        CALL sp_RegisterBookCopy(4, 1, 1, @UnauthorizedCopyID);
    END;
    SELECT CASE WHEN v_Rejected THEN 'PASS' ELSE 'FAIL' END AS UnassignedDirectorRejected;

    SET v_Rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_Rejected = TRUE;
        UPDATE AuditEvent SET EventType = 'TAMPERED' WHERE AuditEventID = 1;
    END;
    SELECT CASE WHEN v_Rejected THEN 'PASS' ELSE 'FAIL' END AS AuditUpdateRejected;
END//
DELIMITER ;

CALL sp_RunExpectedFailureTests();
DROP PROCEDURE sp_RunExpectedFailureTests;
-- END database/05_validation/030_smoke_tests.sql

SELECT 'KOHA_LITE_BUILD_COMPLETE' AS BuildStatus, DATABASE() AS DatabaseName, VERSION() AS MySQLVersion;
