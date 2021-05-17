CREATE PROCEDURE [AsyncAgent].[Private_AddTsqlJobStep] (
 @JobName NVARCHAR(128)
,@StepName NVARCHAR(128)
,@Command NVARCHAR(4000) = N''
,@DatabaseName NVARCHAR(128) = NULL
,@ValidateSyntax BIT = 0
)
AS
BEGIN

	SET XACT_ABORT ON;

	DECLARE @_Msg NVARCHAR(1000);


	---- VALIDATE
	IF ISNULL( @JobName, '' ) = ''
		THROW 50001, N'Job name must not be empty!', 0
	;

	IF ISNULL( @DatabaseName, '' ) = ''
		SET @DatabaseName = DB_NAME();

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

	IF DB_ID( @DatabaseName ) IS NULL
	BEGIN
		SET @_Msg = N'Database ''' + @DatabaseName + ''' doesn''t exist! Check your input please.';
		THROW 50004, @_Msg, 0
	END
	;

	-- #FIX: Find better method for syntax validation.
	-- DM view used here is always evaluated in current DB context (even when called dynamically).
	-- If cross-DB code has to be validated then value of @Command has to contain according
	-- three-part names!
	-- Additional cases have been identified that cause errors in this validation. Actually
	-- there are none and statement would execute correctly (e.g. if proc uses temp tables).
	IF @ValidateSyntax = 1 AND EXISTS (
		SELECT TOP 1 1
		FROM [sys].[dm_exec_describe_first_result_set] ( @Command, NULL, 0 )
		WHERE [error_number] IS NOT NULL
	)
	BEGIN
		SELECT @Command;
		THROW 50005, N'T-SQL code for job step might be erroneous. Please check or set parameter @ValidateSyntax to 0 to create job step either way. Make sure, cross database references are fully qualified (three-part name).', 0
	END
	;


	---- ACT
	EXEC [msdb].[dbo].[sp_add_jobstep]
		 @job_name = @JobName
		,@step_name = @StepName
		,@subsystem = N'TSQL'
		,@command = @Command
		,@database_name = @DatabaseName
	;

	RETURN 0;

END
