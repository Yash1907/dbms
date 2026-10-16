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

