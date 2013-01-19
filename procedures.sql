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
DROP PROCEDURE IF EXISTS PopulateChild;

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
 * POPULATES THE PARENT TABLE WITH amount ENTRIES
 * PARAM
 * dbName: name of database
 * tableName: name of table
 * amount: amount of entries to insert into parent table
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

/*
 * POPULATES A TABLE WITH ENTRIES DEPENDING ON WHAT ENTRIES PARENT HAS
 * PARAM
 * dbName: name of database
 * tableName: name of table
 * parentName: name of table that our table depends on
 * amount: how many entries per instance of parent table to make
 */
CREATE PROCEDURE PopulateChild(
    IN dbName           tinyText,
    IN parentName       tinyText,
    IN tableName        tinyText,
    IN amount           INT)
BEGIN
    /* SOME INITIALIZERS */
    SET @distinct_parent_elements := 1;
    SET @total_parent_elements := 1;
    SET @distinct_table_elements := 1;
    SET @total_table_elements := 1;
    SET @remainder_add := 1;
    SET @row_number := 0;
    SET @temp_one := 0;
    SET @temp_two := 0;
    SET @temp_three := 0;

    /* DROP TEMP TABLES IF THEY EXIST */
    SET @ddl=CONCAT('DROP TABLE IF EXISTS `',dbName,'`.`temp1`, `',dbName,'`.`temp2`, `',dbName,'`.`temp3`');
    prepare stmt FROM @ddl;
    EXECUTE stmt;

    /* OBTAIN HOW MANY DISTINCT ELEMENTS PARENT TABLE HAS */
    SET @ddl=CONCAT('SELECT COUNT(DISTINCT `',dbName,'`.`',parentName,'`.`',parentName,'_type`) INTO @distinct_parent_elements FROM `',dbName,'`.`',parentName,'`');
    prepare stmt FROM @ddl;
    EXECUTE stmt;

    /* OBTAIN HOW MANY ELEMENTS PARENT TABLE HAS */
    SET @ddl=CONCAT('SELECT COUNT(*) INTO @total_parent_elements FROM `',dbName,'`.`',parentName,'`');
    prepare stmt FROM @ddl;
    EXECUTE stmt;
    SET @total_parent_elements := @total_parent_elements / @distinct_parent_elements;

    /* OBTAIN HOW MANY DISTINCT ELEMENTS TABLE HAS */
    SET @ddl=CONCAT('SELECT COUNT(DISTINCT `',dbName,'`.`',tableName,'`.`',tableName,'_type`) INTO @distinct_table_elements FROM `',dbName,'`.`',tableName,'`');
    prepare stmt FROM @ddl;
    EXECUTE stmt;

    /* MAKE SURE WE DO NOT DIVIDE BY ZERO */
    IF @distinct_table_elements = 0
        THEN
            SET @total_table_elements := 0;
    ELSE
        /* OBTAIN HOW MANY ELEMENTS TABLE HAS */
        SET @ddl=CONCAT('SELECT COUNT(*) INTO @total_table_elements FROM `',dbName,'`.`',tableName,'`');
        prepare stmt FROM @ddl;
        EXECUTE stmt;
        SET @total_table_elements := @total_table_elements / @distinct_table_elements;
    END IF;

    /* DROP TEMP TABLES IF THEY EXIST (CLEAN UP JUST IN CASE) */
    SET @ddl=CONCAT('DROP TABLE IF EXISTS `',dbName,'`.`temp1`, `',dbName,'`.`temp2`');
    prepare stmt FROM @ddl;
    EXECUTE stmt;

    /* OBTAIN ALL THE UNIQUE ELEMENT NAMES AND STORE THEM SO LATER ON WE CAN CYCLE THROUGH THEM */
    /* PUT ALL THE UNIQUE NAME TYPES IN THE TABLE */
    SET @ddl=CONCAT('CREATE TABLE `',dbName,'`.`temp2` SELECT DISTINCT`',dbName,'`.`',parentName,'`.`',parentName,'_type` FROM `',dbName,'`.`',parentName,'`');
    prepare stmt FROM @ddl;
    EXECUTE stmt;
    /* ADD A COUNTER TO THEM */
    SET @row_number := 0;
    SET @ddl=CONCAT('CREATE TABLE `',dbName,'`.`temp1` SELECT @row_number := @row_number + 1 row_number, `',dbName,'`.`temp2`.* FROM `',dbName,'`.`temp2`');
    prepare stmt FROM @ddl;
    EXECUTE stmt;
    /* CLEAN UP */
    SET @ddl=CONCAT('DROP TABLE IF EXISTS `',dbName,'`.`temp2`');
    prepare stmt FROM @ddl;
    EXECUTE stmt;

    /* QUICK INITIALIZATION */
    SET @temp_one := 0;

    /* WHILE LOOP THAT LOOPS AS MANY TIMES AS THERE ARE DISTINCT PARENTS */
    WHILE @temp_one < @distinct_parent_elements DO
        SET @temp_one := @temp_one + 1;

        /* OBTAIN PARENT TYPE temp_one AND STORE IT IN current_type */
        SET @current_type := 'NONE';
        SET @ddl=CONCAT('SELECT ',
                                 '`',parentName,'_type` ',
                                        'INTO @current_type ',
                            'FROM ',
                                 '`',dbName,'`.`temp1` ',
                            'WHERE ',
                                 '`temp1`.`row_number` = ',@temp_one);
        prepare stmt FROM @ddl;
        EXECUTE stmt;

        /* DROP TEMP TABLES IF THEY EXIST (CLEAN UP JUST IN CASE) */
        SET @ddl=CONCAT('DROP TABLE IF EXISTS `',dbName,'`.`temp2`, `',dbName,'`.`temp3`');
        prepare stmt FROM @ddl;
        EXECUTE stmt;

        /* OBTAIN ALL THE PARENT ROWS THAT ARE LINKED WITH A CERTAIN TYPE */
        SET @ddl=CONCAT('CREATE TABLE `',dbName,'`.`temp3` ',
                            'SELECT ',
                                 '`',dbName,'`.`',parentName,'`.`',parentName,'_id`, ',
                                 '`',dbName,'`.`',parentName,'`.`',parentName,'_type` ',
                            'FROM ',
                                 '`',dbName,'`.`',parentName,'` ',
                            'WHERE ',
                                 '`',parentName,'`.`',parentName,'_type` = \'',@current_type,'\'');
        prepare stmt FROM @ddl;
        EXECUTE stmt;
        /* ADD A COUNTER TO THEM */
        SET @row_number := 0;
        SET @ddl=CONCAT('CREATE TABLE `',dbName,'`.`temp2` SELECT @row_number := @row_number + 1 row_number, `',dbName,'`.`temp3`.* FROM `',dbName,'`.`temp3`');
        prepare stmt FROM @ddl;
        EXECUTE stmt;
        /* CLEAN UP */
        SET @ddl=CONCAT('DROP TABLE IF EXISTS `',dbName,'`.`temp3`');
        prepare stmt FROM @ddl;
        EXECUTE stmt;

        SET @temp_two := 0;

        /* LOOP AS MANY TIMES AS THERE ARE ELEMENTS IN THE PARENT */
        WHILE @temp_two < @total_parent_elements DO
            SET @temp_two := @temp_two + 1;

            /* OBTAIN ID OF THE PARENT THAT HAS TYPE current_type */
            SET @id_number := 0;
            SET @ddl=CONCAT('SELECT ',
                                     '`temp2`.`',parentName,'_id` ',
                                            'INTO @id_number ',
                                'FROM ',
                                     '`',dbName,'`.`temp2` ',
                                'WHERE ',
                                     '`temp2`.`row_number` = ',@temp_two);
            prepare stmt FROM @ddl;
            EXECUTE stmt;

            /* SEE IF THE CHILD HAS THE LINKING TO PARENT */
            SET @existance := 0;
            SET @ddl=CONCAT('SELECT ',
                                     'COUNT(*) ',
                                            'INTO @existance ',
                                'FROM ',
                                     '`',dbName,'`.`',tableName,'` ',
                                'WHERE ',
                                     '`',tableName,'`.`',tableName,'_',parentName,'_id` = ',@id_number);
            prepare stmt FROM @ddl;
            EXECUTE stmt;

            /* IF WE HAVE LESS INSTANCES PER ENTRY THAN NEEDED */
            IF @existance < amount
                THEN
                    /* LOOP UNTIL WE HAVE AS MANY INSTANCES PER PARENT TABLE ROW AS NEEDED */
                    WHILE @existance < amount DO
                        SET @existance := @existance + 1;

                        SET @ddl=CONCAT('INSERT INTO `',dbName,'`.`',tableName,'` (',
                                                    '`',tableName,'_',parentName,'_id`, '
                                                    '`',tableName,'_type`) ',
                                        'VALUES( ',
                                                    '\'',@id_number,'\', ',
                                                    '\'',tableName,'_',@existance,'\')');
                        prepare stmt FROM @ddl;
                        EXECUTE stmt;
                    END WHILE;
            END IF;

        END WHILE;

    END WHILE;

    /* DROP TEMP TABLES IF THEY EXIST */
    SET @ddl=CONCAT('DROP TABLE IF EXISTS `',dbName,'`.`temp1`, `',dbName,'`.`temp2`, `',dbName,'`.`temp3`');
    prepare stmt FROM @ddl;
    EXECUTE stmt;

END;

//

DELIMITER ;
