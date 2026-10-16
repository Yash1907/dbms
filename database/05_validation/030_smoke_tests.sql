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

