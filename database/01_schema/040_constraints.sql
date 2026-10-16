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
