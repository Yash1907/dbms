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

