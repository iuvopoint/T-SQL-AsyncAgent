CREATE PROCEDURE [AgentTests].[Test Agent job step is correctly created]
AS
BEGIN

	-- Align
	DECLARE @JobName NVARCHAR(128) = N'Test job';

	DECLARE @ExpectedStep NVARCHAR(128) = N'Test step';
	DECLARE @ActualStep NVARCHAR(128) = NULL;

	-- Act
	EXEC [AsyncAgent].[Private_CreateJob] @JobName = @JobName;

	EXEC [AsyncAgent].[Private_AddTsqlJobStep]
		 @JobName = @JobName
		,@StepName = @ExpectedStep
		,@Command = N'some invalid T-SQL for testing purposes'
		,@ValidateSyntax = DEFAULT
	;

	SET @ActualStep = (
		SELECT TOP 1 [Step].[step_name]
		FROM [msdb].[dbo].[sysjobsteps] AS [Step]
		INNER JOIN [msdb].[dbo].[sysjobs] AS [Job] ON
			[Step].[job_id] = [Job].[job_id]
		WHERE [Job].[name] = @JobName AND [Step].[step_name] = @ExpectedStep
	);

	-- Assert
	EXEC [tSQLt].[AssertEquals] @Expected = @ExpectedStep, @Actual = @ActualStep;

	RETURN 0;

END
