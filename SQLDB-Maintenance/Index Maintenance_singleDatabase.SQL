/*
Title: Index reorganizing/rebuilding
Current Version: 2.5
Author: Mohamed Sharaf  @mohamsharaf	| Msharaf.com
Modified Date: 2014-09-07
History:
This script is used to rebuild/reorganize the indexes that needs so. the script logs the actions in a database table in a database called dbAdmin. 
Version: fixing the bug of discovering dataType(max) and adding support for SQL 2012
Version: change the options of the cursor
Version: version 2.2 depend on operation_stats instead of usage_stats
Version: version 2.3 avoid rebuilding online with MDOP>1 & page locks disabled
Version: version 2.4 take care of secondary AG replicas, readonly and snapshot databases
Version: version 2.5 checking the version before checking the seconday AG replicas to enable pre 2012
*/


/*
--Setup of logging table
drop table dbo.INDEXMaintenanceLog;
GO
CREATE TABLE dbo.INDEXMaintenanceLog
(DatabaseName nvarchar(128),Operation varchar(25),StartDate DateTime, EndDate DateTime, Duration_s int, LogInfo varchar(max));
*/
GO

--USE $(DatabaseName)

--Declare variables
--Configuration variables (changable)
DECLARE @useOnlineIndexing BIT;
DECLARE @SORT_IN_TEMPDB CHAR(3); 
DECLARE @minPagestoConsider SMALLINT; 
DECLARE @MDOP TINYINT;
DECLARE @SCRIPT_STARTDATE DATETIME;
DECLARE @SCRIPT_ENDDATE DATETIME;
DECLARE @MinNumberOfScansToConsider INT;
DECLARE @WhenPageLockOFFandReBuilding VARCHAR(20);

--non configuration variables (don't change)
DECLARE @object_id INT ,
    @tableName NVARCHAR(128) ,
    @index_id INT ,
    @name NVARCHAR(128) ,
    @schemaName NVARCHAR(128) ,
    @index_level INT ,
    @alloc_unit_type_desc VARCHAR(50) ,
    @avg_fragmentation_in_percent FLOAT ,
    @page_count BIGINT ,
    @avg_page_space_used_in_percent FLOAT ,
    @fill_factor TINYINT ,
    @Allow_Page_Locks BIT ,
    @SQLVersion TINYINT;

DECLARE @sqlText NVARCHAR(MAX)
DECLARE @tmpDateTime DATETIME
DECLARE @infoMessages VARCHAR(MAX)
DECLARE @newLineChar AS CHAR(2) 

--set values
--------Configuration-----------
SET @useOnlineIndexing = 1;
SET @SORT_IN_TEMPDB = 'OFF';
  --change it to ON to sort in tempdb 
SET @minPagestoConsider = 1000;
  --8MB indexes
SET @MDOP = 8;
  --Max Degree of Parallelism. Change it to 1 to reduce the number of CPUs involved in rebuilding the index
SET @MinNumberOfScansToConsider = 1000;
 --how many range scans to consider 
SET @WhenPageLockOFFandReBuilding = 'EnablePageLock';
 --either 'EnablePageLock' or 'SetMDOP1'
/* When building index online with MDOP>1 & Page locks disabled, would cause more fragmentation. deciding the best action either enable Page locks then disable it
or set the MDOP=1 */
--------------------------------
--loggging
SET @newLineChar = CHAR(13) + CHAR(10)
SET @infoMessages = '--' + DB_NAME() + ' - REBUILDING INDICES --'
    + CONVERT(VARCHAR(40), GETDATE(), 120) + '----' + @newLineChar
SET @SCRIPT_STARTDATE = GETDATE();

--detecting version
 SET @SQLVersion = SUBSTRING(CONVERT(NVARCHAR(20), SERVERPROPERTY('ProductVersion')),
                                                        1,
                                                        CHARINDEX('.',
                                                              CONVERT(NVARCHAR(20), SERVERPROPERTY('ProductVersion')))
                                                        - 1);

--Checking whether the database is readonly,snapshot or part of AG secondary replica
IF EXISTS(SELECT database_id FROM sys.databases WHERE database_id=db_id() AND (is_read_only=1 OR source_database_id IS NOT null) )
BEGIN
	SET @infoMessages = @infoMessages + ' Skipping Database because it is readonly or a database snapshot';
	GOTO Logging;
END
IF @SQLVersion >= 11
BEGIN
	IF EXISTS (SELECT  DB_NAME(drs.database_id) 'Database' ,
			ag.name 'Group_name' ,
			ar.replica_server_name ,
			drs.is_local ,
			drs.database_state_desc ,
			rs.role ,
			rs.role_desc
	FROM    sys.dm_hadr_database_replica_states drs
			JOIN sys.availability_groups ag ON drs.group_id = ag.group_id
			JOIN sys.availability_replicas ar ON drs.replica_id = ar.replica_id
			JOIN sys.dm_hadr_availability_replica_states rs ON drs.group_id = rs.group_id AND drs.replica_id = rs.replica_id
			JOIN sys.databases d ON drs.database_id=d.database_id
			WHERE d.group_database_id IS NOT NULL AND (drs.database_id=DB_ID() AND ar.replica_server_name = @@SERVERNAME AND rs.role=2) )
	BEGIN
		SET @infoMessages = @infoMessages + ' Skipping Database because it is a secondary database in Availability Group';
		GOTO Logging;
	END
END

/*-------------------------------------------------------------------------------------------------------------------------*/

--loop through all indexes that has only pages > @minPagestoConsider and leaf level only
DECLARE cur_Indexes CURSOR LOCAL FORWARD_ONLY READ_ONLY
FOR
    SELECT  f.object_id ,
            OBJECT_NAME(f.object_id) AS tableName ,
            f.index_id ,
            i.name ,
            s.name AS schemaName ,
            f.index_level ,
            f.alloc_unit_type_desc ,
            f.avg_fragmentation_in_percent ,
            f.page_count ,
            f.avg_page_space_used_in_percent ,
            i.fill_factor ,
            allow_page_locks
    FROM    sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL,
                                           'Limited') f
            JOIN sys.indexes i ON f.object_id = i.object_id
                                  AND f.index_id = i.index_id
            JOIN sys.tables t ON i.object_id = t.object_id
            JOIN sys.schemas s ON t.schema_id = s.schema_id
            JOIN sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL) os ON os.object_id = i.object_id
                                                              AND os.index_id = i.index_id
    WHERE   index_level = 0
            AND page_count >= @minPagestoConsider
            AND f.index_id > 0
            AND alloc_unit_type_desc = 'IN_ROW_DATA'
            AND os.range_scan_count >= @MinNumberOfScansToConsider
    ORDER BY f.object_id ,
            f.index_id;

OPEN cur_Indexes

FETCH NEXT FROM cur_Indexes 
INTO @object_id, @tableName, @index_id, @name, @schemaName, @index_level,
    @alloc_unit_type_desc, @avg_fragmentation_in_percent, @page_count,
    @avg_page_space_used_in_percent, @fill_factor, @Allow_Page_Locks

WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @avg_fragmentation_in_percent <= 30
            AND @avg_fragmentation_in_percent > 5
            BEGIN --reorganize
	
		--check if Allow_page_locks option is disabled for this index
                IF @Allow_Page_Locks = 0 --Allow_page_locks disabled, we cannot reorganize without enabling it. we will enable it and then disable it back again.
                    SET @sqlText = N'ALTER INDEX [' + @name + N'] ON ['
                        + @schemaName + N'].[' + @tableName
                        + N'] set (ALLOW_PAGE_LOCKS=ON); ALTER INDEX ['
                        + @name + N'] ON [' + @schemaName + N'].['
                        + @tableName + N'] REORGANIZE; ALTER INDEX [' + @name
                        + N'] ON [' + @schemaName + N'].[' + @tableName
                        + N'] set (ALLOW_PAGE_LOCKS=OFF);'
                ELSE
                    SET @sqlText = N'ALTER INDEX [' + @name + N'] ON ['
                        + @schemaName + N'].[' + @tableName + N'] REORGANIZE;'
			
                BEGIN TRY
                    SET @infoMessages = @infoMessages + @SqlText
                        + @newLineChar
                    SET @tmpDateTime = GETDATE()
                    EXEC sp_executesql @sqlText;
                    SET @infoMessages = @infoMessages + 'Operation took: '
                        + CAST(DATEDIFF(ss, @tmpDateTime, GETDATE()) AS VARCHAR(20))
                        + ' second(s)' + @newLineChar
                END TRY
                BEGIN CATCH
                    SET @infoMessages = @infoMessages + 'ERROR:: Number '
                        + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' | Message: '
                        + ERROR_MESSAGE() + @newLineChar
                END CATCH
		
            END
	
        ELSE
            IF @avg_fragmentation_in_percent > 30
                BEGIN --rebuild
                    IF @useOnlineIndexing = 1
                        AND ( CHARINDEX('Enterprise',
                                        CAST(SERVERPROPERTY('edition') AS NVARCHAR(100))) <> 0
                              OR CHARINDEX('Developer',
                                           CAST(SERVERPROPERTY('edition') AS NVARCHAR(100))) <> 0
                            ) --rebuilding online
                        BEGIN
			
                            IF @SQLVersion < 11
                                AND EXISTS ( SELECT c.name
                                             FROM   sys.columns c --we cannot rebuild any of the indexes for this table online
                                                    JOIN sys.types t ON c.system_type_id = t.system_type_id
                                             WHERE  object_id = @object_id
                                                    AND LOWER(t.name) IN (
                                                    'image', 'text', 'ntext',
                                                    'varchar', 'nvarchar',
                                                    'varbinary', 'xml' )
                                                    AND c.max_length = -1 )
                                SET @sqlText = N'ALTER INDEX [' + @name
                                    + N'] ON [' + @schemaName + N'].['
                                    + @tableName + N'] REBUILD WITH(MAXDOP='
                                    + CAST(@MDOP AS CHAR(3))
                                    + ',SORT_IN_TEMPDB=' + @SORT_IN_TEMPDB
                                    + ');'
                            ELSE
								/*
								Check if Page lock is off and MDOP>1, this will cause more fragmentation as documented in http://support.microsoft.com/kb/2292737
								*/
                                IF @Allow_Page_Locks = 0
                                    AND @MDOP > 1
                                    BEGIN
                                        IF @WhenPageLockOFFandReBuilding = 'EnablePageLock'
                                            BEGIN
                                                SET @sqlText = N'ALTER INDEX ['
                                                    + @name + N'] ON ['
                                                    + @schemaName + N'].['
                                                    + @tableName
                                                    + N'] set (ALLOW_PAGE_LOCKS=ON);ALTER INDEX ['
                                                    + @name + N'] ON ['
                                                    + @schemaName + N'].['
                                                    + @tableName
                                                    + N'] REBUILD WITH (ONLINE = ON,MAXDOP='
                                                    + CAST(@MDOP AS CHAR(3))
                                                    + ',SORT_IN_TEMPDB='
                                                    + @SORT_IN_TEMPDB
                                                    + ');ALTER INDEX ['
                                                    + @name + N'] ON ['
                                                    + @schemaName + N'].['
                                                    + @tableName
                                                    + N'] set (ALLOW_PAGE_LOCKS=OFF);'
                                            END
                                        ELSE --When @WhenPageLockOFFandReBuilding='SetMDOP1'
                                            BEGIN
                                                SET @sqlText = N'ALTER INDEX ['
                                                    + @name + N'] ON ['
                                                    + @schemaName + N'].['
                                                    + @tableName
                                                    + N'] REBUILD WITH(MAXDOP=1,SORT_IN_TEMPDB='
                                                    + @SORT_IN_TEMPDB + ');'
                                            END
                                    END
                                ELSE
                                    BEGIN
                                        SET @sqlText = N'ALTER INDEX ['
                                            + @name + N'] ON [' + @schemaName
                                            + N'].[' + @tableName
                                            + N'] REBUILD WITH (ONLINE = ON,MAXDOP='
                                            + CAST(@MDOP AS CHAR(3))
                                            + ',SORT_IN_TEMPDB='
                                            + @SORT_IN_TEMPDB + ');'
                                    END

                        END
                    ELSE
                        BEGIN 
                            SET @sqlText = N'ALTER INDEX [' + @name
                                + N'] ON [' + @schemaName + N'].['
                                + @tableName + N'] REBUILD WITH(MAXDOP='
                                + CAST(@MDOP AS CHAR(3)) + ',SORT_IN_TEMPDB='
                                + @SORT_IN_TEMPDB + ');'
                        END	
                    PRINT @sqlText;
                    BEGIN TRY
                        SET @infoMessages = @infoMessages + @sqlText
                            + @newLineChar
                        SET @tmpDateTime = GETDATE()
                        EXEC sp_executesql @sqlText;
                        SET @infoMessages = @infoMessages + 'Operation took: '
                            + CAST(DATEDIFF(ss, @tmpDateTime, GETDATE()) AS VARCHAR(20))
                            + ' second(s)' + @newLineChar
                    END TRY
                    BEGIN CATCH
                        SET @infoMessages = @infoMessages + 'ERROR:: Number '
                            + CAST(ERROR_NUMBER() AS VARCHAR(10))
                            + ' | Message: ' + ERROR_MESSAGE() + @newLineChar
                    END CATCH
		
                END
        FETCH NEXT FROM cur_indexes 
	INTO @object_id, @tableName, @index_id, @name, @schemaName, @index_level,
            @alloc_unit_type_desc, @avg_fragmentation_in_percent, @page_count,
            @avg_page_space_used_in_percent, @fill_factor, @Allow_Page_Locks
    END

--clear allocation
CLOSE cur_indexes
DEALLOCATE cur_indexes


Logging:
--flush logging
SET @SCRIPT_ENDDATE = GETDATE();

SELECT  DB_NAME() AS DatabaseName ,
        'Index Rebuilding' AS Operation ,
        @SCRIPT_STARTDATE AS Start_Date ,
        @SCRIPT_ENDDATE AS End_Date ,
        DATEDIFF(SECOND, @SCRIPT_STARTDATE, @SCRIPT_ENDDATE) AS duration ,
        @infoMessages AS infoMessages;
INSERT  dbAdmin.dbo.INDEXMaintenanceLog
        ( DatabaseName ,
          Operation ,
          StartDate ,
          EndDate ,
          Duration_s ,
          LogInfo
        )
VALUES  ( DB_NAME() ,
          'Index Rebuilding' ,
          @SCRIPT_STARTDATE ,
          @SCRIPT_ENDDATE ,
          DATEDIFF(SECOND, @SCRIPT_STARTDATE, @SCRIPT_ENDDATE) ,
          @infoMessages
        );






