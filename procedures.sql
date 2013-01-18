USE SOME_DATABASE;

/* PROCEDURE RESET */
DROP PROCEDURE IF EXISTS AddTableUnlessExists;
DROP PROCEDURE IF EXISTS AddParentTableUnlessExists;
DROP PROCEDURE IF EXISTS AddChildTableUnlessExists;
DROP PROCEDURE IF EXISTS CreateParentTable;
DROP PROCEDURE IF EXISTS CreateChildTable;
DROP PROCEDURE IF EXISTS AddColumnUnlessExists;
DROP PROCEDURE IF EXISTS RenameType;
DROP PROCEDURE IF EXISTS PopulateParent;

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

/*
 * ADDS AND POPULATES A COLUMN IF IT DOESN'T EXIST
 * PARAM
 * dbName: name of database
 * tableName: name of table
 * fieldName: column that will be added if it doesn't exist
 * fieldDef: definition of the column that will be added
 * default_value: default value that will populate the whole table for the column being added
 */
CREATE PROCEDURE AddColumnUnlessExists(
    IN dbName           tinytext,
    IN tableName        tinytext,
    IN fieldName        tinytext,
    IN fieldDef         text,
    IN default_value    text,
    IN incrementation   INT,
    IN ignore_parent    INT)
BEGIN
    /* CHECK TO SEE IF COLUMN EXISTS */
    IF NOT EXISTS   (
                        SELECT * FROM information_schema.COLUMNS
                            WHERE   column_name=fieldName
                                AND table_name=tableName
                                AND table_schema=dbName
                    )
    THEN
        /* COLUMN DIDN'T EXIST, SO CREATE COLUMN CREATION QUERY */
        SET @ddl=CONCAT('ALTER TABLE `',dbName,'`.`',tableName,'` ',
                        'ADD COLUMN ',fieldName,' ',fieldDef,' ',default_value);
        /* EXECUTE CREATION QUERY */
        prepare stmt FROM @ddl;
        EXECUTE stmt;
        /* IF USER WANTS TO INCREMENT VALUES INSIDE A TABLE */
        IF incrementation = 1
            THEN
            IF ignore_parent = 1
            THEN
                SET @ddl=CONCAT('UPDATE `',dbName,'`.`',tableName,'` AS `temp1` ',
                                'JOIN ',
                                '( ',
                                '   SELECT DISTINCT(`',dbName,'`.`',tableName,'`.`',tableName,'_id`), ',
                                '          @i:=@i+1 AS counter ',
                                '   FROM `',dbName,'`.`',tableName,'`, ',
                                '        ( ',
                                '           SELECT @i:=',default_value,'-1 ',
                                '        ) AS cnt ',
                                ') AS `temp2` ',
                                'ON  `temp1`.`',tableName,'_id` = `temp2`.`',tableName,'_id` ',
                                'SET `temp1`.`',fieldName,'`    = `temp2`.`counter`;');
                /* EXECUTE INSERTION QUERY */
                prepare stmt FROM @ddl;
                EXECUTE stmt;
            ELSE
                SET @ddl=CONCAT('UPDATE `',dbName,'`.`',tableName,'` AS `temp1` ',
                                'JOIN ',
                                '( ',
                                '   SELECT DISTINCT(`',dbName,'`.`',tableName,'`.`',tableName,'_type`), ',
                                '          @i:=@i+1 AS counter ',
                                '   FROM `',dbName,'`.`',tableName,'`, ',
                                '        ( ',
                                '           SELECT @i:=',default_value,'-1 ',
                                '        ) AS cnt ',
                                '   GROUP BY `',dbName,'`.`',tableName,'`.`',tableName,'_type` ',
                                ') AS `temp2` ',
                                'ON  `temp1`.`',tableName,'_type`  = `temp2`.`',tableName,'_type` ',
                                'SET `temp1`.`',fieldName,'`       = `temp2`.`counter`;');
                /* EXECUTE INSERTION QUERY */
                prepare stmt FROM @ddl;
                EXECUTE stmt;
            END IF;
        ELSE
            /* CREATE INSERTION QUERY */
            SET @ddl=CONCAT('UPDATE `',dbName,'`.`',tableName,'` ',
                            'SET ',fieldName,' = ',default_value);
            /* EXECUTE INSERTION QUERY */
            prepare stmt FROM @ddl;
            EXECUTE stmt;
        END IF;
    END IF;
END;

CREATE PROCEDURE RenameType(
    IN dbName           tinytext,
    IN tableName        tinytext,
    IN oldValue         text,
    IN newValue         text)
BEGIN
    /* CREATE UPDATE QUERY */
    SET @ddl=CONCAT('UPDATE `',dbName,'`.`',tableName,'` ',
                        'SET ',tableName,'_type = \'',newValue,'\' ',
                        'WHERE `',tableName,'_type` = \'',tableName,'_',oldValue,'\'');
    /* EXECUTE UPDATE QUERY */
    prepare stmt FROM @ddl;
    EXECUTE stmt;
END;

//

DELIMITER ';'

DELIMITER //

/*
 * POPULATES THE PARENT TABLE (USUALLY PROFILE) WITH amount ENTRIES
 * PARAM
 * dbName: name of database
 * tableName: name of table
 * amount: amount of entries to insert into profile
 */
CREATE PROCEDURE PopulateParent(
    IN dbName           tinytext,
    IN tableName        tinytext,
    IN amount           INT)
BEGIN
    /* COUNT HOW MANY ENTRIES EXIST CURRENTLY */
    SET @current_amount := 1;
    SET @ddl=CONCAT('SELECT COUNT(*) INTO @current_amount FROM `',dbName,'`.`',tableName,'`');
    prepare stmt FROM @ddl;
    EXECUTE stmt;
    /* LOOP UNTIL POPULATED */
    WHILE @current_amount < amount DO
        SET @current_amount = @current_amount + 1;
        SET @ddl=CONCAT('INSERT INTO `',dbName,'`.`',tableName,'`(',
                        '`',tableName,'_type`) ',
                        'VALUES(\'MAIN\')');
        prepare stmt FROM @ddl;
        EXECUTE stmt;
    END WHILE;
END;

//

DELIMITER ;
