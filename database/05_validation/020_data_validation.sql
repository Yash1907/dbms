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

