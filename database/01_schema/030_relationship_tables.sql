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

