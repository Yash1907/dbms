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

