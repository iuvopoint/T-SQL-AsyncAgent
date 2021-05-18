CREATE FUNCTION [AsyncAgent].[IsJobRunning] (
 @JobName NVARCHAR(128)
,@RunRequestedBefore DATETIME = NULL
)
RETURNS BIT
AS
BEGIN

	IF @RunRequestedBefore IS NULL
		SET @RunRequestedBefore = GETDATE();

	IF EXISTS (
		SELECT TOP 1 [Job].[name]
		FROM [msdb].[dbo].[sysjobactivity] AS [Activity]
		INNER JOIN [msdb].[dbo].[sysjobs] AS [Job] ON
				[Activity].[job_id] = [Job].[job_id]
			AND [Job].[name] = @JobName
		WHERE
				[run_requested_date] <= @RunRequestedBefore
			AND [start_execution_date] IS NOT NULL
			AND [stop_execution_date] IS NULL
	)
		RETURN 1
	;

	RETURN 0;

END
