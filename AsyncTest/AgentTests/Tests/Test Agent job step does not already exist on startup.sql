CREATE PROCEDURE [AgentTests].[Test Agent job step does not already exist on startup]
AS
BEGIN

	-- Align
	DECLARE @ExpectedStep NVARCHAR(128) = NULL;
	DECLARE @ActualStep NVARCHAR(128) = NULL;

	-- Act
	SET @ActualStep = (
		SELECT TOP 1 [Step].[step_name]
		FROM [msdb].[dbo].[sysjobsteps] AS [Step]
		INNER JOIN [msdb].[dbo].[sysjobs] AS [Job] ON
			[Step].[job_id] = [Job].[job_id]
		WHERE [Job].[name] = N'Test job' AND [Step].[step_name] = N'Test step'
	);

	-- Assert
	EXEC [tSQLt].[AssertEquals] @Expected = @ExpectedStep, @Actual = @ActualStep;

	RETURN 0;

END
