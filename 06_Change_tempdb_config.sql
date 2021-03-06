--=====================================================================================================
--
-- This script is meant to run from powershell script
-- 
--=====================================================================================================

--:CONNECT SQL01
-- check current configuration and cpu
-- sys.database_files show the current size
-- sys.master_files show the size at the time of creation

DECLARE @path			NVARCHAR(512) = (SELECT LEFT(physical_name,LEN(physical_name) - CHARINDEX('\', REVERSE(physical_name))) 
											FROM sys.master_files 
											WHERE database_id = 2
											AND file_id = 1)
DECLARE @FileSize_MB	SMALLINT = 1024
DECLARE @FileGrowth_MB	SMALLINT = 1024
DECLARE @LogSize_MB		SMALLINT = 4096
DECLARE @LogGrowth_MB	SMALLINT = 4096
DECLARE @SQL			NVARCHAR(4000)
DECLARE @debugging		BIT = 1

DECLARE @cores_per_numa_node	INT
DECLARE @n_data_files		INT

SELECT -- [database_name] = 'tempdb', 
		@cores_per_numa_node = (SELECT t.hyperthread_ratio / COUNT(DISTINCT s.parent_node_id) AS physical_cores_per_numa_node 
				FROM sys.dm_os_schedulers AS s
					CROSS APPLY (SELECT hyperthread_ratio FROM sys.dm_os_sys_info) AS t
				WHERE s.status = N'VISIBLE ONLINE'
				GROUP BY t.hyperthread_ratio
			)
		, @n_data_files			= COUNT(*)
		--, biggest_file_size_MB  = CONVERT(DECIMAL(10,2), (MAX(df.size) * 8 / 1024.))
		--, smallest_file_size_MB = CONVERT(DECIMAL(10,2), (MIN(df.size) * 8 / 1024.))
		--, average_file_size_MB  = CONVERT(DECIMAL(10,2), (AVG(df.size) * 8 / 1024.))
		--, total_size_MB			= CONVERT(DECIMAL(10,2), (SUM(df.size) * 8 / 1024.))
		--, log_size_MB			= CONVERT(DECIMAL(10,2), (SUM(lf.size) * 8 / 1024.))
	FROM tempdb.sys.database_files AS df
		CROSS APPLY (SELECT lf.size FROM tempdb.sys.database_files AS lf WHERE lf.type_desc = 'LOG') AS lf
	WHERE df.type_desc = 'ROWS'

IF (CASE WHEN @cores_per_numa_node > 8 THEN 8 ELSE @cores_per_numa_node END) > @n_data_files BEGIN

	;WITH tempdb_files AS(
	SELECT 1 AS id
	UNION ALL
	SELECT tempdb_files.id + 1
		FROM tempdb_files
		WHERE tempdb_files.id < (CASE WHEN @cores_per_numa_node > 8 THEN 8 ELSE @cores_per_numa_node END)
	)
	SELECT 'ALTER DATABASE tempdb MODIFY FILE(NAME=''tempdev'', SIZE=' + CONVERT(VARCHAR(30),@FileSize_MB) + 'MB, FILEGROWTH=' + CONVERT(VARCHAR(30),@FileGrowth_MB) + 'MB)' AS AddModifyFile
		INTO #cmd
	UNION ALL
	SELECT 'ALTER DATABASE tempdb MODIFY FILE(NAME=''templog'', SIZE=' + CONVERT(VARCHAR(30),@LogSize_MB) + 'MB, FILEGROWTH=' + CONVERT(VARCHAR(30),@LogGrowth_MB) + 'MB)' AS AddFile
	UNION ALL
	SELECT 'ALTER DATABASE tempdb ADD FILE(NAME=''tempdev_' + CONVERT(VARCHAR(30),tempdb_files.id+1) + ''', ' + 
										 'FILENAME=''' + @path + '\tempdev_' + CONVERT(VARCHAR(30),tempdb_files.id+1) + '.ndf'', ' + 
										 'SIZE=' + CONVERT(VARCHAR(30),@FileSize_MB) + 'MB, ' + 
										 'FILEGROWTH=' + CONVERT(VARCHAR(30),@FileGrowth_MB) + 'MB)' AS AddFile		
		FROM tempdb_files
		WHERE tempdb_files.id < (CASE WHEN @cores_per_numa_node > 8 THEN 8 ELSE @cores_per_numa_node END);

	DECLARE cr CURSOR LOCAL FAST_FORWARD FORWARD_ONLY READ_ONLY FOR
		SELECT AddModifyFile FROM #cmd

	OPEN cr 

	FETCH NEXT FROM cr INTO @SQL

	WHILE @@FETCH_STATUS = 0 BEGIN
		IF @debugging = 0 BEGIN
			EXECUTE sys.sp_executesql @SQL
		END 
		ELSE BEGIN
			PRINT @SQL
		END

		FETCH NEXT FROM cr INTO @SQL
	END

	CLOSE cr
	DEALLOCATE cr
END
ELSE BEGIN
	SELECT  [database_name] = 'tempdb'
			, cores_per_numa_node = @cores_per_numa_node
			, n_data_files			= COUNT(*)
			, biggest_file_size_MB  = CONVERT(DECIMAL(10,2), (MAX(df.size) * 8 / 1024.))
			, smallest_file_size_MB = CONVERT(DECIMAL(10,2), (MIN(df.size) * 8 / 1024.))
			, average_file_size_MB  = CONVERT(DECIMAL(10,2), (AVG(df.size) * 8 / 1024.))
			, total_size_MB			= CONVERT(DECIMAL(10,2), (SUM(df.size) * 8 / 1024.))
			, log_size_MB			= CONVERT(DECIMAL(10,2), (SUM(lf.size) * 8 / 1024.))
	FROM tempdb.sys.database_files AS df
		CROSS APPLY (SELECT lf.size FROM tempdb.sys.database_files AS lf WHERE lf.type_desc = 'LOG') AS lf
	WHERE df.type_desc = 'ROWS'

	
END
