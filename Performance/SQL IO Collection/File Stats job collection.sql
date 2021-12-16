/*
Author:Mohamed Sharaf (@mohamsharaf)
Mohamed.Sharaf

Originally From http://www.sqlskills.com/blogs/paul/how-to-examine-io-subsystem-latencies-from-within-sql-server/

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

SET NOCOUNT ON;
DECLARE @currentTime DATETIME;
SET @currentTime = GETDATE();

IF NOT EXISTS ( SELECT  t.name
                FROM    sys.tables t
                        JOIN sys.schemas s ON t.schema_id = s.schema_id
                WHERE   t.name = 'tmpFileStats'
                        AND s.name = 'perf' )
    BEGIN
        SELECT  @currentTime AS 'CollectionTime' ,
    --virtual file latency
                [vfs].database_id ,
                [vfs].file_id ,
                [ReadLatency_ms] = CASE WHEN [num_of_reads] = 0 THEN 0
                                        ELSE ( [io_stall_read_ms]
                                               / [num_of_reads] )
                                   END ,
                [WriteLatency_ms] = CASE WHEN [num_of_writes] = 0 THEN 0
                                         ELSE ( [io_stall_write_ms]
                                                / [num_of_writes] )
                                    END ,
    --avg bytes per IOP
                [AvgBPerRead] = CASE WHEN [num_of_reads] = 0 THEN 0
                                     ELSE ( [num_of_bytes_read]
                                            / [num_of_reads] )
                                END ,
                [AvgBPerWrite] = CASE WHEN [io_stall_write_ms] = 0 THEN 0
                                      ELSE ( [num_of_bytes_written]
                                             / [num_of_writes] )
                                 END ,
                [AvgBPerTransfer] = CASE WHEN ( [num_of_reads] = 0
                                                AND [num_of_writes] = 0
                                              ) THEN 0
                                         ELSE ( ( [num_of_bytes_read]
                                                  + [num_of_bytes_written] )
                                                / ( [num_of_reads]
                                                    + [num_of_writes] ) )
                                    END ,
	--IOPS
				[num_of_reads]=vfs.num_of_reads,
				[num_of_writes]=vfs.num_of_writes,
				[num_of_IOs]=vfs.num_of_reads+vfs.num_of_writes,
                
				
				LEFT([mf].[physical_name], 2) AS [Drive] ,
                DB_NAME([vfs].[database_id]) AS [DB] ,
                [vfs].size_on_disk_bytes / 1024 / 1024 AS size_on_disk_MB ,
                [mf].[physical_name] ,
                [vfs].sample_ms
        INTO    perf.tmpFileStats
        FROM    sys.dm_io_virtual_file_stats(NULL, NULL) AS [vfs]
                JOIN sys.master_files AS [mf] ON [vfs].[database_id] = [mf].[database_id]
                                                 AND [vfs].[file_id] = [mf].[file_id];

    END
ELSE
    BEGIN

        IF NOT EXISTS ( SELECT  t.name
                        FROM    sys.tables t
                                JOIN sys.schemas s ON t.schema_id = s.schema_id
                        WHERE   t.name = 'FileStats'
                                AND s.name = 'perf' )
            BEGIN
                CREATE TABLE [perf].[FileStats]
                    (
                      [CollectionTime] [datetime] NOT NULL ,
                      [ReadLatency_ms] [bigint] NOT NULL ,
                      [ReadLatency_delta_ms] BIGINT NOT NULL ,
                      [WriteLatency_ms] [bigint] NOT NULL ,
                      [WriteLatency_delta_ms] BIGINT NOT NULL ,
                      [AvgBPerRead] [bigint] NOT NULL ,
                      [AvgBPerWrite] [bigint] NOT NULL ,
                      [AvgBPerTransfer] [bigint] NOT NULL ,
                      [num_of_reads_perSec] INT NOT NULL,
					  [num_of_writes_perSec] INT NOT NULL,
					  [num_of_IOs_perSec] INT NOT NULL,
					  [Drive] [nvarchar](2) NOT NULL ,
                      [DB] [nvarchar](128) NOT NULL ,
                      [size_on_disk_MB] [bigint] NOT NULL ,
                      [physical_name] [nvarchar](260) NOT NULL ,
                      [sample_ms] [int] NOT NULL
                    )
                ON  [PRIMARY]
            END

        INSERT  perf.FileStats
                SELECT  @currentTime AS 'CollectionTime' ,
    --virtual file latency
                        [ReadLatency_ms] = CASE WHEN [vfs].[num_of_reads] = 0 THEN 0
                                                ELSE ( [io_stall_read_ms]
                                                       / [vfs].[num_of_reads] )
                                           END ,
                        [ReadLatency_delta_ms] = [ReadLatency_ms]
                        - tmp.ReadLatency_ms ,
                        [WriteLatency_ms] = CASE WHEN [vfs].[num_of_writes] = 0
                                                 THEN 0
                                                 ELSE ( [io_stall_write_ms]
                                                        / [vfs].[num_of_writes] )
                                            END ,
                        [WriteLatency_delta_ms] = [WriteLatency_ms]
                        - tmp.WriteLatency_ms ,
    --avg bytes per IOP
                        [AvgBPerRead] = CASE WHEN [vfs].[num_of_reads] = 0 THEN 0
                                             ELSE ( [num_of_bytes_read]
                                                    / [vfs].[num_of_reads] )
                                        END ,
                        [AvgBPerWrite] = CASE WHEN [io_stall_write_ms] = 0
                                              THEN 0
                                              ELSE ( [num_of_bytes_written]
                                                     / [vfs].[num_of_writes] )
                                         END ,
                        [AvgBPerTransfer] = CASE WHEN ( [vfs].[num_of_reads] = 0
                                                        AND [vfs].[num_of_writes] = 0
                                                      ) THEN 0
                                                 ELSE ( ( [num_of_bytes_read]
                                                          + [num_of_bytes_written] )
                                                        / ( [vfs].[num_of_reads]
                                                            + [vfs].[num_of_writes] ) )
                                            END ,
--IOPS
						[num_of_reads_perSec]=([vfs].[num_of_reads]-tmp.[num_of_reads])/(DATEDIFF(SECOND,tmp.CollectionTime,@currentTime)),
						[num_of_writes_perSec]=(vfs.num_of_writes-tmp.[num_of_writes])/(DATEDIFF(SECOND,tmp.CollectionTime,@currentTime)),
						[num_of_IOs_perSec]=((vfs.num_of_reads+vfs.num_of_writes)-(tmp.[num_of_reads]+tmp.[num_of_writes]))/(DATEDIFF(SECOND,tmp.CollectionTime,@currentTime)),

                        LEFT([mf].[physical_name], 2) AS [Drive] ,
                        DB_NAME([vfs].[database_id]) AS [DB] ,
                        [vfs].size_on_disk_bytes / 1024 / 1024 AS size_on_disk_MB ,
                        [mf].[physical_name] ,
                        [vfs].sample_ms
                FROM    sys.dm_io_virtual_file_stats(NULL, NULL) AS [vfs]
                        JOIN sys.master_files AS [mf] ON [vfs].[database_id] = [mf].[database_id]
                                                         AND [vfs].[file_id] = [mf].[file_id]
                        JOIN perf.tmpFileStats tmp ON vfs.database_id = tmp.database_id
                                                      AND vfs.file_id = tmp.file_id;
    END


