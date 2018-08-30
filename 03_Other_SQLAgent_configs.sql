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


-- Configure the MAX number of ERRORLOG files to 30, there'll be a job to cycle it every day if bigger than a threshold, 
USE [master]
GO
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'NumErrorLogs', REG_DWORD, 30
GO
