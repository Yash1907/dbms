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
