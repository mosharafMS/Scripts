/*
Check the compression estimate for the top 50 tables. 
Author: Mohamed Sharaf (Mohamed.Sharaf@Microsoft.com)

Errors expected from the script when encountering xml columns, just ignore them

--Disclaimer
Sample scripts in this guide are not supported under any Microsoft standard support program or service. 
The sample scripts are provided AS IS without warranty of any kind. 
Microsoft disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. 
The entire risk arising out of the use or performance of the sample scripts and documentation remains with you. 
In no event shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the sample scripts or documentation, even if Microsoft has been advised of the possibility of such damages. 
*/


DECLARE @compressionType NVARCHAR(20);

--change the value for the desired compression type
SET @compressionType=N'PAGE' --takes PAGE or RAW

DECLARE @schemaName sysname,@tableName sysname,@usedPagesMB INT
,@reservedPagesMB INT,@indexID INT,@objectID INT;

IF object_id('tempdb..#ResultTable') IS NOT NULL
BEGIN
   DROP TABLE #ResultTable
END
CREATE TABLE #ResultTable (object_name sysname,schema_name sysname,index_id INT,partition_number INT
,compressionType NVARCHAR(20) NULL
,[size_with_current_compression_setting(KB)] BIGINT
,[size_with_requested_compression_setting(KB)]  BIGINT
,[sample_size_with_current_compression_setting(KB)] BIGINT
,[sample_size_with_requested_compression_setting(KB)] BIGINT
,CompressionRatio AS CONVERT(DECIMAL(16,2),[size_with_requested_compression_setting(KB)])/ CONVERT(DECIMAL(16,2),NULLIF([size_with_current_compression_setting(KB)],0))*100
,user_seeks BIGINT null
,user_scans BIGINT null
,user_lookups BIGINT null
,user_updates BIGINT null
,Read_to_write_percentage INT null)


--Cursor start
DECLARE cur_tables CURSOR FOR   
SELECT TOP 50 s.name 'Schema',t.name 'Table',ps.object_id,ps.index_id ,SUM(ps.used_page_count)/128 'used_pages_MB',SUM(ps.reserved_page_count)/128 'reserved_pages_MB'
FROM
sys.dm_db_partition_stats ps 
JOIN sys.tables t ON ps.object_id=t.object_id
JOIN sys.schemas s ON s.schema_id=t.schema_id
GROUP BY s.name,t.name,ps.object_id,ps.index_id
ORDER BY used_pages_MB DESC,reserved_pages_MB DESC


OPEN cur_tables;
FETCH cur_tables INTO @schemaName,@tableName,@objectID,@indexID,@usedPagesMB,@reservedPagesMB
WHILE @@FETCH_STATUS=0
BEGIN
BEGIN TRY	
	INSERT #ResultTable
	        ( object_name ,
	          schema_name ,
	          index_id ,
	          partition_number ,
	          [size_with_current_compression_setting(KB)] ,
	          [size_with_requested_compression_setting(KB)] ,
	          [sample_size_with_current_compression_setting(KB)] ,
	          [sample_size_with_requested_compression_setting(KB)]) EXEC sp_estimate_data_compression_savings @schemaName,@tableName,@indexID,NULL,@compressionType;
END TRY
BEGIN CATCH
PRINT 'catch'
			INSERT #ResultTable
	        ( object_name ,
	          schema_name ,
	          index_id ,
	          partition_number ,
	          [size_with_current_compression_setting(KB)] ,
	          [size_with_requested_compression_setting(KB)] ,
	          [sample_size_with_current_compression_setting(KB)] ,
	          [sample_size_with_requested_compression_setting(KB)]) Values (@tableName,@schemaName,@indexID,-1,-1,-1,-1,-1)
END CATCH	
	UPDATE #ResultTable SET compressionType=@compressionType;
	UPDATE rt
	SET rt.user_seeks=istat.user_seeks
	,rt.user_scans=istat.user_scans
	,rt.user_lookups=istat.user_lookups
	,rt.user_updates=istat.user_updates
	,rt.Read_to_write_percentage=istat.Read_to_write_percentage
	FROM #ResultTable rt
	JOIN (SELECT object_id,index_id,user_seeks,user_scans,user_lookups,user_updates,
CASE user_updates WHEN 0 THEN 100
ELSE user_seeks+user_scans+user_lookups/user_updates
END AS 'Read_to_write_percentage'
 FROM sys.dm_db_index_usage_stats 
WHERE object_id=@objectID AND index_id=@indexID AND database_id=DB_ID()) iStat 
ON istat.index_id=rt.index_id 

	FETCH cur_tables INTO @schemaName,@tableName,@objectID,@indexID,@usedPagesMB,@reservedPagesMB
END


CLOSE cur_tables;
DEALLOCATE cur_tables;
--cursor end

SELECT * FROM #ResultTable