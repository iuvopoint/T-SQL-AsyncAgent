CREATE PROCEDURE [AgentTests].[Test Agent job does not already exist on startup]
AS
BEGIN

	-- Align
	DECLARE @ExpectedJob NVARCHAR(128) = NULL;
	DECLARE @ActualJob NVARCHAR(128) = NULL;

	-- Act
	SET @ActualJob = (
		SELECT TOP 1 [name]
		FROM [msdb].[dbo].[sysjobs]
		WHERE [name] = N'Test job'
	);

	-- Assert
	EXEC [tSQLt].[AssertEquals] @Expected = @ExpectedJob, @Actual = @ActualJob;

	RETURN 0;

END
