CREATE PROCEDURE [AgentTests].[Test Started Agent job is running]
AS
BEGIN

	-- Align
	DECLARE @ExpectedJob NVARCHAR(128) = N'Test job';
	DECLARE @ActualJob NVARCHAR(128) = NULL;

	-- Act
	EXEC [AsyncAgent].[Private_CreateJob] @JobName = @ExpectedJob;
	EXEC [AsyncAgent].[Private_AddTsqlJobStep]
		 @JobName = @ExpectedJob
		,@StepName = N'Wait for 5 seconds'
		,@Command = N'WAITFOR DELAY N''00:00:10'';'
		,@ValidateSyntax = 1
	;

	-- Job cannot be started if its creation is yet uncommitted.
	-- WARNING: This is mandatory for testing but will break tSQLt transaction handling!
	COMMIT;

	EXEC [AsyncAgent].[Private_StartJob] @JobName = @ExpectedJob;

	-- Wait for the job to be started
	WAITFOR DELAY N'00:00:02';

	SET @ActualJob = (
		SELECT TOP 1 [Job].[name]
		FROM [msdb].[dbo].[sysjobactivity] AS [Activity]
		INNER JOIN [msdb].[dbo].[sysjobs] AS [Job] ON
				[Activity].[job_id] = [Job].[job_id]
			AND [Job].[name] = @ExpectedJob
		WHERE
				[run_requested_date] <= GETDATE()
			AND [start_execution_date] IS NOT NULL
			AND [stop_execution_date] IS NULL
	);

	-- Cleanup manually, as tSQLt won't roll back
	EXEC [msdb].[dbo].[sp_delete_job] @job_name = @ExpectedJob;
	EXEC [msdb].[dbo].[sp_delete_category] @class = N'JOB', @name = N'Async';

	-- Assert
	BEGIN TRAN -- Mandatory, as ROLLBACK is called by tSQLt right after this assertion.
	EXEC [tSQLt].[AssertEquals] @Expected = @ExpectedJob, @Actual = @ActualJob;

	RETURN 0;

END
