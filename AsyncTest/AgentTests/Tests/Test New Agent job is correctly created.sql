CREATE PROCEDURE [AgentTests].[Test New Agent job is correctly created]
AS
BEGIN

	-- Align
	DECLARE @ExpectedJob NVARCHAR(128) = N'Test job';
	DECLARE @ActualJob NVARCHAR(128) = NULL;

	-- Act
	EXEC [AsyncAgent].[Private_CreateJob] @JobName = @ExpectedJob;

	SET @ActualJob = (
		SELECT TOP 1 [name]
		FROM [msdb].[dbo].[sysjobs]
		WHERE [name] = @ExpectedJob
	);

	-- Assert
	EXEC [tSQLt].[AssertEquals] @Expected = @ExpectedJob, @Actual = @ActualJob;

	RETURN 0;

END
