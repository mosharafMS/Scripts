/*
Collecting SQL Server performance counters related to memory to do memory assessment for the instance


Author:Mohamed Sharaf	Tiwtter:@mohamsharaf
Mohamed.Sharaf@Microsoft.com 

*/

/*SETUP ONLY use when needed 
IF NOT EXISTS(SELECT database_id FROM sys.databases WHERE name='dbAdmin')
BEGIN
	CREATE DATABASE dbAdmin;
	ALTER DATABASE dbAdmin SET RECOVERY SIMPLE;
END
GO
USE dbAdmin;
GO
CREATE SCHEMA perf
GO
*/

USE dbAdmin;

SET NOCOUNT ON;

--Get the instance name that will be attached to the object name 
DECLARE @instanceName NVARCHAR(100);
SET @instanceName = ( SELECT    CONVERT(NVARCHAR(100), SERVERPROPERTY('InstanceName'))
                    );
IF @instanceName IS NULL
    SET @instanceName = 'SQLServer:';
ELSE
    SET @instanceName = 'MSSQL$' + @instanceName + ':';



DECLARE @counters TABLE
    (
      objectName NVARCHAR(150) COLLATE database_default,
      counterName NVARCHAR(150) COLLATE database_default
    );
INSERT  @counters
        ( objectName ,
          counterName
        )
VALUES  ( @instanceName + N'Buffer Manager' ,
          N'Total pages'
        )

INSERT  @counters
        ( objectName ,
          counterName
        )
VALUES  ( @instanceName + N'Buffer Manager' ,
          N'Database pages'
        ) 

INSERT  @counters
        ( objectName ,
          counterName
        )
VALUES  ( @instanceName + N'Buffer Manager' ,
          N'Lazy writes/sec'
        )

INSERT  @counters
        ( objectName ,
          counterName
        )
VALUES  ( @instanceName + N'Buffer Manager' ,
          N'Page reads/sec'
        )

INSERT  @counters
        ( objectName ,
          counterName
        )
VALUES  ( @instanceName + N'Buffer Manager' ,
          N'Page writes/sec'
        )

INSERT  @counters
        ( objectName ,
          counterName
        )
VALUES  ( @instanceName + N'Buffer Manager' ,
          N'Page life expectancy'
        )

INSERT  @counters
        ( objectName ,
          counterName
        )
VALUES  ( @instanceName + N'Buffer Manager' ,
          N'Page lookups/sec'
        )

INSERT  @counters
        ( objectName ,
          counterName
        )
VALUES  ( @instanceName + N'Memory Manager' ,
          N'Total Server Memory (KB)'
        )

INSERT  @counters
        ( objectName ,
          counterName
        )
VALUES  ( @instanceName + N'Memory Manager' ,
          N'Memory Grants Outstanding'
        )

INSERT  @counters
        ( objectName ,
          counterName
        )
VALUES  ( @instanceName + N'Memory Manager' ,
          N'Memory Grants Pending'
        )

INSERT  @counters
        ( objectName ,
          counterName
        )
VALUES  ( @instanceName + N'SQL Statistics' ,
          N'Batch Requests/sec'
        )

---------------------------------------------------------------------------------

--creating the table that will hold the performance counters
IF NOT EXISTS ( SELECT  t.name
                FROM    sys.tables t
                        JOIN sys.schemas s ON t.schema_id = s.schema_id
                WHERE   t.name = 'SQLperformanceCounters'
                        AND s.name = 'perf' )
    BEGIN
        CREATE TABLE perf.SQLperformanceCounters
            (
			  collectionID BIGINT IDENTITY(1,1) PRIMARY KEY NONCLUSTERED,
              collectionTime DATETIME NOT NULL ,
              object_name NVARCHAR(128) NOT NULL ,
              counter_name NVARCHAR(128) NOT NULL ,
              instance_name NVARCHAR(128) NULL ,
              cntr_value BIGINT ,
              cntr_type INT
            );

       CREATE CLUSTERED INDEX  IX_SQLperformanceCounters_CollectionTime ON perf.SQLperformanceCounters(collectionTime,object_name,counter_name,instance_name)

    END
-----------------------------------------------------------
--capture current time
DECLARE @currentTime AS DATETIME;
SET @currentTime = GETDATE();

IF NOT EXISTS ( SELECT  t.name
                FROM    sys.tables t
                        JOIN sys.schemas s ON t.schema_id = s.schema_id
                WHERE   t.name = 'tmpSQLCounters'
                        AND s.name = 'perf' ) 
    BEGIN	
        SELECT  @currentTime AS 'collectionTime' ,
                perf.object_name ,
                perf.counter_name ,
                perf.instance_name ,
                perf.cntr_value ,
                perf.cntr_type
        INTO    perf.tmpSQLCounters
        FROM    sys.dm_os_performance_counters perf
                JOIN @counters ON perf.object_name = [@counters].objectName COLLATE database_default
                                  AND perf.counter_name = [@counters].counterName COLLATE database_default
        ORDER BY perf.object_name ,
                perf.counter_name COLLATE database_default;
    END
ELSE
    BEGIN
	--get last collection time from the temp table
        DECLARE @lastcollectionTime DATETIME;
        SET @lastcollectionTime = ( SELECT  MAX(collectionTime)
                                    FROM    perf.tmpSQLCounters
                                  );
        DECLARE @secondsElapsed INT;
        SET @secondsElapsed = DATEDIFF(SECOND, @lastcollectionTime,
                                       @currentTime);

	--hold the current collection temporary 
	  DECLARE @currentCounterReadings TABLE
            (
              collectionTime DATETIME NOT NULL ,
              OBJECT_NAME NVARCHAR(128) NOT NULL ,
              counter_name NVARCHAR(128) NOT NULL ,
              instance_name NVARCHAR(128) NULL ,
              cntr_value BIGINT ,
              cntr_type INT
            )
		

        INSERT  @currentCounterReadings
                SELECT  @currentTime AS 'collectionTime' ,
                        perf.object_name ,
                        perf.counter_name ,
                        perf.instance_name ,
                        perf.cntr_value ,
                        perf.cntr_type
                FROM    sys.dm_os_performance_counters perf
                        JOIN @counters ON perf.object_name = [@counters].objectName COLLATE database_default
                                          AND perf.counter_name = [@counters].counterName COLLATE database_default
                ORDER BY perf.object_name ,
                        perf.counter_name COLLATE database_default;


        INSERT  perf.SQLperformanceCounters
                SELECT  collectionTime ,
                        OBJECT_NAME ,
                        counter_name ,
                        instance_name ,
                        cntr_value ,
                        cntr_type
                FROM    @currentCounterReadings
                WHERE   cntr_type = 65792;


        INSERT  perf.SQLperformanceCounters
                SELECT  c.collectionTime ,
                        c.OBJECT_NAME ,
                        c.counter_name ,
                        c.instance_name ,
                        (( c.cntr_value - p.cntr_value ) / @secondsElapsed) AS cntr_value,
                        c.cntr_type
                FROM    @currentCounterReadings c
                        JOIN perf.tmpSQLCounters p ON c.OBJECT_NAME = p.OBJECT_NAME COLLATE database_default
                                                   AND c.counter_name = p.counter_name COLLATE database_default
                                                   AND ( c.instance_name IS NULL
                                                         OR c.instance_name = p.instance_name COLLATE database_default
                                                       ) 
                WHERE   c.cntr_type = 272696576;


				--truncate the temp table and refill it with the current load
				
				TRUNCATE TABLE perf.tmpSQLCounters

				
				INSERT perf.tmpSQLCounters 
					SELECT  collectionTime ,
				        OBJECT_NAME ,
				        counter_name ,
				        instance_name ,
				        cntr_value ,
				        cntr_type FROM @currentCounterReadings

    END