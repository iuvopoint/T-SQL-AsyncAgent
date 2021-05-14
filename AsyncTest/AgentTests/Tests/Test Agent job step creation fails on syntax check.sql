CREATE PROCEDURE [AgentTests].[Test Agent job step creation fails on syntax check]
AS
BEGIN

	-- Align
	DECLARE @JobName NVARCHAR(128) = N'Test job';
	DECLARE @StepName NVARCHAR(128) = N'Test step';

	DECLARE @ExpectedStep NVARCHAR(128) = N'Test step';
	DECLARE @ActualStep NVARCHAR(128) = NULL;

	-- Act
	EXEC [AsyncAgent].[Private_CreateJob] @JobName = @JobName;

	-- Assert
	EXEC [tSQLt].[ExpectException] @ExpectedMessagePattern = N'%@ValidateSyntax%';

	EXEC [AsyncAgent].[Private_AddTsqlJobStep]
		 @JobName = @JobName
		,@StepName = @ExpectedStep
		,@Command = N'invalid T-SQL command'
		,@ValidateSyntax = 1
	;

	RETURN 0;

END
