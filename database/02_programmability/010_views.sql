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

