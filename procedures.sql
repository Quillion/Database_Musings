USE SOME_DATABASE;

/* PROCEDURE RESET */
DROP PROCEDURE IF EXISTS AddTableUnlessExists;
DROP PROCEDURE IF EXISTS AddParentTableUnlessExists;
DROP PROCEDURE IF EXISTS AddChildTableUnlessExists;
DROP PROCEDURE IF EXISTS CreateParentTable;
DROP PROCEDURE IF EXISTS CreateChildTable;

/* PROCEDURE CREATION */
DELIMITER '//'

/*
 * CREATES TABLE WITHOUT DEPENDANCIES
 * PARAMS
 * dbName: name of database
 * tableName: name of table name that will be created
 */
CREATE PROCEDURE CreateParentTable(
    IN dbName           tinytext,
    IN tableName        tinytext)
BEGIN
        /* CREATE QUERY */
        SET @dll = CONCAT('CREATE TABLE IF NOT EXISTS `',dbName,'`.`',tableName,'` (',
                          '`',tableName,'_id`                   INT                 NOT NULL    AUTO_INCREMENT , ',
                          '`',tableName,'_type`                 VARCHAR(255)        NOT NULL    DEFAULT \'no_name_SET\' , ',
                          'PRIMARY KEY (`',tableName,'_id`) ',
                          ') ENGINE = INNODB DEFAULT CHARSET=latin1');
        /* EXECUTE IT */
        prepare stmt FROM @dll;
        EXECUTE stmt;
END;

/*
 * CREATES A TABLE THAT DEPENDS ON A PARENT TABLE
 * PARAMS
 * dbName: name of database
 * tableName: name of table name that will be created
 * parentTable: name of parent table that the table depends on
 */
CREATE PROCEDURE CreateChildTable(
    IN dbName           tinytext,
    IN parentTable      tinytext,
    IN tableName        tinytext)
BEGIN
        /* CREATE QUERY */
        SET @dll = CONCAT('CREATE TABLE IF NOT EXISTS `',dbName,'`.`',tableName,'` (',
                          '`',tableName,'_id`                   INT                 NOT NULL    AUTO_INCREMENT , ',
                          '`',tableName,'_',parentTable,'_id`   INT                 NOT NULL    DEFAULT \'0\' , '
                          '`',tableName,'_type`                 VARCHAR(31)         NOT NULL    DEFAULT \'NO TYPE\' , '
                          'PRIMARY KEY (`',tableName,'_id`) , ',
                          'FOREIGN KEY (`',tableName,'_',parentTable,'_id`) ',
                          '     REFERENCES `',parentTable,'` (`',parentTable,'_id`) ON DELETE CASCADE ON UPDATE CASCADE',
                          ') ENGINE = INNODB DEFAULT CHARSET=latin1');
        /* EXECUTE IT */
        prepare stmt FROM @dll;
        EXECUTE stmt;
END;

/*
 * ADDS A CUSTOM TABLE IF IT DOESN'T EXIST
 * PARAMS
 * dbName: name of database
 * tableName: name of table name that will be created if it doesn't exist
 * fieldDef: creation query for the table
 */
CREATE PROCEDURE AddTableUnlessExists(
    IN dbName           tinytext,
    IN tableName        tinytext,
    IN fieldDef         text)
BEGIN
    /* CHECK TO SEE IF TABLE DOES NOT EXIST */
    IF NOT EXISTS   (
                        SELECT * FROM information_schema.TABLES
                            WHERE   table_name = tableName
                                AND table_schema = dbName
                    )
    THEN
        /* IT DOESN'T EXIST, SO WE CREATE IT */
        SET @dll = CONCAT('CREATE TABLE IF NOT EXISTS `',dbName,'`.`',tableName,'` ',fieldDef);
        prepare stmt FROM @dll;
        EXECUTE stmt;
    END IF;
END;

/*
 * ADDS AN INDEPENDANT TABLE IF IT DOESN'T EXIST
 * PARAMS
 * dbName: name of database
 * tableName: name of table name that will be created if it doesn't exist
 */
CREATE PROCEDURE AddParentTableUnlessExists(
    IN dbName           tinytext,
    IN tableName        tinytext)
BEGIN
    /* CHECK TO SEE IF TABLE DOES NOT EXIST */
    IF NOT EXISTS   (
                        SELECT * FROM information_schema.TABLES
                            WHERE   table_name = tableName
                                AND table_schema = dbName
                    )
    THEN
        /* IT DOESN'T EXIST, SO WE CREATE IT */
        CALL CreateParentTable(dbName, tableName);
    END IF;
END;

/*
 * ADDS A DEPENDANT TABLE IF IT DOESN'T EXIST
 * PARAMS
 * dbName: name of database
 * tableName: name of table name that will be created if it doesn't exist
 * parentTable: name of parent table that the table depends on
 */
CREATE PROCEDURE AddChildTableUnlessExists(
    IN dbName           tinytext,
    IN parentTable      tinytext,
    IN tableName        tinytext)
BEGIN
    /* CHECK TO SEE IF TABLE DOES NOT EXIST */
    IF NOT EXISTS   (
                        SELECT * FROM information_schema.TABLES
                            WHERE   table_name = tableName
                                AND table_schema = dbName
                    )
    THEN
        /* IT DOESN'T EXIST, SO WE CREATE IT */
        CALL CreateChildTable(dbName, parentTable, tableName);
    END IF;
END;

//

DELIMITER ;
