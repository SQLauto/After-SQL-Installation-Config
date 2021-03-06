--=====================================================================================================
--
-- This script is meant to run from powershell script
-- 
--=====================================================================================================
-- Add important SQL Agent Alerts to your instance
-- Change the @OperatorName as needed
--:CONNECT SQL01

USE [msdb];
GO

-- Make sure you have an Agent Operator defined
-- Change @OperatorName as needed
DECLARE @OperatorName sysname = N'DatabaseAdministrators';

-- Change @CategoryName as needed
DECLARE @CategoryName sysname = N'SQL Server Agent Alerts';

-- Add Alert Category if it does not exist
IF NOT EXISTS (SELECT *
               FROM msdb.dbo.syscategories
               WHERE category_class = 2  -- ALERT
               AND category_type = 3
               AND name = @CategoryName)
BEGIN
    EXEC msdb.dbo.sp_add_category @class = N'ALERT', @type = N'NONE', @name = @CategoryName;
END

-- Get the server name
DECLARE @ServerName			SYSNAME = (SELECT @@SERVERNAME);
DECLARE @AlertName			SYSNAME;
DECLARE @Severity			SYSNAME;
DECLARE @ErrorNumber		SYSNAME;
DECLARE @language_id		INT		= (SELECT lcid FROM sys.syslanguages WHERE name = @@LANGUAGE)
DECLARE @include_AG_Alerts	BIT = 1

DECLARE alerts CURSOR READ_ONLY FORWARD_ONLY FOR 
	SELECT 17 AS Severity, 0 AS ErrorNumber, @ServerName + N' Alert - Sev 17 Error: An operation made SQL Server out of resources or exceeding defined limit' AS AlertName
	UNION ALL
	SELECT 18 AS Severity, 0,	@ServerName + N' Alert - Sev 18 Error: Nonfatal internal software error'
	UNION ALL
	SELECT 19 AS Severity, 0,	@ServerName + N' Alert - Sev 19 Error: Fatal Error in Resource'
	UNION ALL
	SELECT 20 AS Severity, 0,	@ServerName + N' Alert - Sev 20 Error: Fatal Error in Current Process'
	UNION ALL
	SELECT 21 AS Severity, 0,	@ServerName + N' Alert - Sev 21 Error: Fatal Error in Database Process'
	UNION ALL
	SELECT 22 AS Severity, 0,	@ServerName + N' Alert - Sev 22 Error: Fatal Error Table Integrity Suspect'
	UNION ALL
	SELECT 23 AS Severity, 0,	@ServerName + N' Alert - Sev 23 Error: Fatal Error Database Integrity Suspect'
	UNION ALL
	SELECT 24 AS Severity, 0,	@ServerName + N' Alert - Sev 24 Error: Fatal Hardware Error'
	UNION ALL
	SELECT 25 AS Severity, 0,	@ServerName + N' Alert - Sev 25 Error: Fatal Error'
	UNION ALL
	SELECT 0 AS Severity, 823,	@ServerName + N' Alert - Error 823: Consistency Error'
	UNION ALL
	SELECT 0 AS Severity, 824,	@ServerName + N' Alert - Error 824: Logical Consistency Error'
	UNION ALL
	SELECT 0 AS Severity, 825,	@ServerName + N' Alert - Error 825: Read-Retry Required'
	UNION ALL 
	-- Availability Groups Alerts (severity < 17)
	SELECT 0 ,		message_id, @ServerName  + N' Alert - Error ' + CONVERT(NVARCHAR,message_id) + N': ' + LEFT(text, 90)
		FROM sys.messages 
		WHERE language_id = @language_id
			--AND message_id IN (35267, 35273, 35274, 35275, 35254, 35279)
			AND message_id IN (1480, 35254, 35264, 35265, 35266, 35267, 35273, 35274, 35275, 35279)
			AND @include_AG_Alerts = 1
			--AND severity < 17
;

OPEN alerts

FETCH NEXT FROM alerts
INTO @Severity, @ErrorNumber, @AlertName

WHILE @@FETCH_STATUS = 0 BEGIN
	
	IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE message_id = @ErrorNumber AND severity = @Severity)

		EXEC msdb.dbo.sp_add_alert 
			@name = @AlertName
			, @message_id = @ErrorNumber
			, @severity = @Severity
			, @enabled = 1
			, @delay_between_responses = 900
			, @include_event_description_in = 1
			, @category_name = @CategoryName
			, @job_id = N'00000000-0000-0000-0000-000000000000';

	-- Add a notification if it does not exist
	IF NOT EXISTS(SELECT *
					FROM msdb.dbo.sysalerts AS sa
						INNER JOIN msdb.dbo.sysnotifications AS sn
							ON sa.id = sn.alert_id
					WHERE sa.message_id = @ErrorNumber 
						AND sa.severity = @Severity)BEGIN
		EXEC msdb.dbo.sp_add_notification 
			@alert_name = @AlertName
			, @operator_name = @OperatorName
			, @notification_method = 1;
	END

	FETCH NEXT FROM alerts
		INTO @Severity, @ErrorNumber, @AlertName
END

CLOSE alerts;

DEALLOCATE alerts;

