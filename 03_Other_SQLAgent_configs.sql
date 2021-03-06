--=====================================================================================================
--
-- This script is meant to run from powershell script
-- 
--=====================================================================================================

-- Define Idle status for job running when idle
USE [msdb]
GO
EXEC msdb.dbo.sp_set_sqlagent_properties 
	@cpu_poller_enabled		= 1
	, @idle_cpu_percent		= 10
	, @idle_cpu_duration	= 600 

GO

-- Define FailSafe operator.
USE [msdb]
GO
EXEC master.dbo.sp_MSsetalertinfo @failsafeoperator=N'DatabaseAdministrators', 
		@notificationmethod=1
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder=1
GO
