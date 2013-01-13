DROP DATABASE IF EXISTS RESET;
CREATE DATABASE RESET;
USE RESET;

DROP PROCEDURE IF EXISTS PurgeOldTable;

DELIMITER '//'
CREATE PROCEDURE PurgeOldTable()
BEGIN
    /* DELETE IF OLDER THAN TO SPECIFIED AGE */
    SET @creation_year := 2012;
    SELECT YEAR(CREATE_TIME)
        INTO @creation_year
        FROM INFORMATION_SCHEMA.TABLES
        /* DATABASE NAME */
            WHERE `TABLE_SCHEMA` = 'SOME_DATABASE'
            /* ANY TABLE NAME FROM THE DATABASE */
                AND `TABLE_NAME` = 'some_table';
    IF @creation_year < 2012
    THEN
        DROP DATABASE IF EXISTS SOME_DATABASE;
        CREATE DATABASE SOME_DATABASE;
    END IF;
END;

//

DELIMITER ';'

CALL PurgeOldTable();

DROP DATABASE IF EXISTS RESET;
CREATE DATABASE IF NOT EXISTS SOME_DATABASE;
