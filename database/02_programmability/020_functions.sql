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

