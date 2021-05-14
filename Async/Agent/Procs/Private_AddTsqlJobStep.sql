CREATE PROCEDURE [AsyncAgent].[Private_AddTsqlJobStep] (
 @JobName NVARCHAR(128)
,@StepName NVARCHAR(128)
,@Command NVARCHAR(4000) = N''
,@ValidateSyntax BIT = 0 -- Currently not applicable for cross-database usage!
)
AS
BEGIN

	SET XACT_ABORT ON;

	DECLARE @_Msg NVARCHAR(1000);

	---- VALIDATE
	IF ISNULL( @JobName, '' ) = ''
		THROW 50001, N'Job name must not be empty!', 0
	;

	IF NOT EXISTS (
		SELECT TOP 1 1
		FROM [msdb].[dbo].[sysjobs]
		WHERE [name] = @JobName
	)
	BEGIN
		SET @_Msg = N'Job ''' + @JobName + ''' does not exist. Can''t add step to a non-existing job. Create job beforehand, please.';
		THROW 50002, @_Msg, 0
	END
	;

	IF ISNULL( @StepName, '' ) = ''
		THROW 50003, N'Step name must not be empty!', 0
	;

	IF @ValidateSyntax = 1 AND EXISTS (
		SELECT TOP 1 1
		FROM [sys].[dm_exec_describe_first_result_set] ( @Command, NULL, 0 )
		WHERE [error_number] IS NOT NULL
	)
		THROW 50004, N'T-SQL code for job step creation seems to be erroneous. Please check or set parameter @ValidateSyntax to 0 to create job step either way.', 0
	;

	---- ACT
	EXEC [msdb].[dbo].[sp_add_jobstep]
		 @job_name = @JobName
		,@step_name = @StepName
		,@subsystem = N'TSQL'
		,@command = @Command
	;

	RETURN 0;

END
