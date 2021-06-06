/*
Bereitstellungsskript für Async

Dieser Code wurde von einem Tool generiert.]D;]A;Änderungen an dieser Datei führen möglicherweise zu falschem Verhalten und gehen verloren, falls]D;]A;der Code neu generiert wird.
*/
GO
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;

SET NUMERIC_ROUNDABORT OFF;


GO
:setvar DatabaseName "@SQL@"

GO
:on error exit
GO
/*
Überprüfen Sie den SQLCMD-Modus, und deaktivieren Sie die Skriptausführung, wenn der SQLCMD-Modus nicht unterstützt wird.]D;]A;Um das Skript nach dem Aktivieren des SQLCMD-Modus erneut zu aktivieren, führen Sie folgenden Befehl aus:]D;]A;SET NOEXEC OFF; ]D;]A;*/
:setvar __IsSqlCmdEnabled "True"
GO
IF N'$(__IsSqlCmdEnabled)' NOT LIKE N'True'
    BEGIN
        PRINT N'Der SQLCMD-Modus muss aktiviert sein, damit dieses Skript erfolgreich ausgeführt werden kann.';
        SET NOEXEC ON;
    END


GO
USE [master];

GO

IF (DB_ID(N'$(DatabaseName)') IS NULL) 
    BEGIN
        PRINT N'Die Datenbank muss existieren, damit dieses Skript erfolgreich ausgeführt werden kann.';
        SET NOEXEC ON;
    END

GO


USE [$(DatabaseName)];

GO
PRINT N'SqlSchema "[AsyncAgent]" wird erstellt...';


GO
CREATE SCHEMA [AsyncAgent]
    AUTHORIZATION [dbo];


GO
PRINT N'SqlScalarFunction "[AsyncAgent].[IsJobRunning]" wird erstellt...';


GO
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
GO
PRINT N'SqlScalarFunction "[AsyncAgent].[IsQuotedSb_Sysname]" wird erstellt...';


GO
CREATE FUNCTION [AsyncAgent].[IsQuotedSb_Sysname] (
 @Sysname NVARCHAR(130)
)
RETURNS BIT
AS
BEGIN

	-- Rules for quoted sysname identifiers:
	-- 1. Must be wrapped in square brackets ( '[...]' )
	-- 2. Sysname must not be empty string ( > '' )
	-- 3. May contain '[' and ']' characters inside wrapping square brackets
	-- 4. Only double occurences of character ']' inside wrapping square brackets allowed

	IF @Sysname IS NULL
		RETURN NULL;

	-- Empty strings ( '' ) are not valid sysnames. '[]' is not a valid quoted sysname.
	-- Min length of 3 ( '[?]' ) required for valid quotation.
	IF LEN( @Sysname ) < 3
		RETURN 0;

	-- Not quoted if not wrapped in square brackets.
	IF NOT EXISTS (
		SELECT TOP 1 1
		WHERE @Sysname LIKE '\[%\]' ESCAPE '\'
		)
		RETURN 0
	;

	-- Remove wrapping square brackets.
	SET @Sysname = SUBSTRING( @Sysname, 2, LEN( @Sysname ) - 2 );

	-- Remove every string of even length containing ']' inside @Sysname.
	-- Odd occurences will remain with one particular ']' character and mark
	-- invalid quotation.
	SET @Sysname = REPLACE( @Sysname, ']]', '' );

	-- If there are no single ']' characters remaining, sysname is validly quoted.
	IF CHARINDEX( N']', @Sysname, 0 ) > 0
		RETURN 0;

	RETURN 1;

END
GO
PRINT N'SqlScalarFunction "[AsyncAgent].[QuoteSb_Sysname]" wird erstellt...';


GO
CREATE FUNCTION [AsyncAgent].[QuoteSb_Sysname] (
 @Sysname NVARCHAR(128)
)
RETURNS NVARCHAR(130)
AS
BEGIN

	-- Returns NULL if @Sysname is NULL, SB quoted string otherwise.

	IF [AsyncAgent].[IsQuotedSb_Sysname]( @Sysname ) = 0
		RETURN QUOTENAME( @Sysname );

	RETURN @Sysname;

END
GO
PRINT N'SqlScalarFunction "[AsyncAgent].[UnquoteSb_Sysname]" wird erstellt...';


GO
CREATE FUNCTION [AsyncAgent].[UnquoteSb_Sysname] (
 @Sysname NVARCHAR(130)
)
RETURNS NVARCHAR(128)
AS
BEGIN

	-- Returns NULL if @Sysname is NULL, SB unquoted string otherwise.

	IF [AsyncAgent].[IsQuotedSb_Sysname]( @Sysname ) = 0
		RETURN @Sysname;

	RETURN SUBSTRING( @Sysname, 2, LEN( @Sysname ) - 2 );

END
GO
PRINT N'SqlScalarFunction "[AsyncAgent].[GetFQProcName]" wird erstellt...';


GO
CREATE FUNCTION [AsyncAgent].[GetFQProcName] (
 @DatabaseName NVARCHAR(130) = NULL
,@SchemaName NVARCHAR(130)
,@ProcName NVARCHAR(130)
)
RETURNS NVARCHAR(392)
AS
BEGIN

	IF ISNULL( @DatabaseName, '' ) = ''
		SET @DatabaseName = DB_NAME();

	DECLARE @_FQProcName NVARCHAR(392) = 
		[AsyncAgent].[QuoteSb_Sysname]( @DatabaseName ) + '.' +
		[AsyncAgent].[QuoteSb_Sysname]( @SchemaName ) + '.' +
		[AsyncAgent].[QuoteSb_Sysname]( @ProcName )
	;

	IF OBJECT_ID( @_FQProcName ) IS NULL
		RETURN NULL;

	RETURN @_FQProcName;

END
GO
PRINT N'SqlScalarFunction "[AsyncAgent].[GetFQProcNameHash]" wird erstellt...';


GO
CREATE FUNCTION [AsyncAgent].[GetFQProcNameHash] (
 @DatabaseName NVARCHAR(130) = NULL
,@SchemaName NVARCHAR(130)
,@ProcName NVARCHAR(130)
)
RETURNS CHAR(32)
AS
BEGIN

	-- Returns MD5 hash of standardized procedure name format. Example:
	-- 'msdb.dbo.SysJobs' returns same hash result as 'msdb.[dbo].sysjobs'

	DECLARE @_FQProcNameHash CHAR(32) = CONVERT( CHAR(32),
		HASHBYTES( 'MD5', UPPER( [AsyncAgent].[GetFQProcName] (
			@DatabaseName, @SchemaName, @ProcName
		) ) ), 2 -- Hex representation without leading '0x'
	);

	RETURN @_FQProcNameHash;
;

END
GO
PRINT N'SqlProcedure "[AsyncAgent].[Private_ReleaseAppLock_Job]" wird erstellt...';


GO
CREATE PROCEDURE [AsyncAgent].[Private_ReleaseAppLock_Job] (
 @JobName NVARCHAR(128)
,@DatabaseName NVARCHAR(128) = NULL
)
AS
BEGIN

	SET XACT_ABORT ON;

	IF ISNULL( @DatabaseName, '' ) = ''
		SET @DatabaseName = DB_NAME();

	DECLARE @_CRLF CHAR(2) = CHAR(13) + CHAR(10);
	DECLARE @_Sql NVARCHAR(4000) =
		N'EXEC ' + [AsyncAgent].[QuoteSb_Sysname]( @DatabaseName ) + '..[sp_releaseapplock]' + @_CRLF +
		N'	 @Resource = @JobName' + @_CRLF +
		N'	,@LockOwner = N''Session''' + @_CRLF +
		N';'
	;
	DECLARE @_ParamDefinition NVARCHAR(1000) =
		N'@JobName NVARCHAR(128)'
	;

	EXEC sp_executesql
		 @stmnt = @_Sql
		,@params = @_ParamDefinition
		,@JobName = @JobName
	;

	RETURN 0;

END
GO
PRINT N'SqlProcedure "[AsyncAgent].[Private_AddTsqlJobStep]" wird erstellt...';


GO
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
	-- Additionally, in some cases this validation throws errors for commands that would execute
	-- successfully.
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
GO
PRINT N'SqlProcedure "[AsyncAgent].[Private_AssembleCommand]" wird erstellt...';


GO
CREATE PROCEDURE [AsyncAgent].[Private_AssembleCommand] (
 @SchemaName NVARCHAR(130)
,@ProcName NVARCHAR(130)
,@FQProcName NVARCHAR(392) OUTPUT
,@FQProcNameHash CHAR(32) OUTPUT
,@Command NVARCHAR(4000) OUTPUT
,@DatabaseName NVARCHAR(130) = NULL
,@AsyncGroup NVARCHAR(128) = NULL
)
AS
BEGIN

	SET XACT_ABORT ON;


	---- INIT
	IF ISNULL( @DatabaseName, '' ) = ''
		SET @DatabaseName = DB_NAME();

	SET @FQProcName = [AsyncAgent].[GetFQProcName] (
		@DatabaseName, @SchemaName, @ProcName )
	;
	SET @FQProcNameHash = [AsyncAgent].[GetFQProcNameHash] (
		@DatabaseName, @SchemaName, @ProcName )

	;

	---- VALIDATE 
	DECLARE @_Msg NVARCHAR(1000);
	IF OBJECT_ID( @FQProcName ) IS NULL
	BEGIN
		SET @_Msg = N'Unknown procedure: ' + @FQProcName + '. Check your input please.';
		THROW 50001, @_Msg, 0
	END
	;


	-- #TODO: Move AppLock management to distinct job steps. Will make sure that these are
	-- called even if there's something wrong with the called proc.
	---- ACT
	DECLARE @CRLF NCHAR(2) = CHAR(13) + CHAR(10);
	SET @Command =
		N'EXEC [sp_getapplock]' + @CRLF +
		N'	 @Resource = N''' + @FQProcNameHash + '''' + @CRLF +
		N'	,@LockMode = N''Exclusive''' + @CRLF +
		N'	,@LockOwner = N''Session''' + @CRLF +
		N';' + @CRLF +
		N'PRINT N''Lock for resource ''''' + @FQProcNameHash + ''''' acquired.'';' + @CRLF +
		N'GO' + @CRLF + @CRLF +

		N'EXEC ' + @FQProcName + ';' + @CRLF +
		N'GO' + @CRLF + @CRLF +

		N'EXEC [sp_releaseapplock]' + @CRLF +
		N'	 @Resource = N''' + @FQProcNameHash + '''' + @CRLF +
		N'	,@LockOwner = N''Session''' + @CRLF +
		N';' + @CRLF +
		N'PRINT N''Lock for resource ''''' + @FQProcNameHash + ''''' released.'';' + @CRLF +
		N'GO'
	;

	IF ISNULL( @AsyncGroup, '' ) > ''
		SET @Command = 
			N'EXEC [sp_getapplock]' + @CRLF +
			N'	 @Resource = N''' + @AsyncGroup + '''' + @CRLF +
			N'	,@LockMode = N''Shared''' + @CRLF +
			N'	,@LockOwner = N''Session''' + @CRLF +
			N';' + @CRLF +
			N'PRINT N''Lock for resource ''''' + @AsyncGroup + ''''' acquired.'';' + @CRLF +
			N'GO' + @CRLF + @CRLF +

			+ @Command + @CRLF + @CRLF +

			N'EXEC [sp_releaseapplock]' + @CRLF +
			N'	 @Resource = N''' + @AsyncGroup + '''' + @CRLF +
			N'	,@LockOwner = N''Session''' + @CRLF +
			N';' + @CRLF +
			N'PRINT N''Lock for resource ''''' + @AsyncGroup + ''''' released.'';' + @CRLF +
			N'GO'
		;


	RETURN 0;

END
GO
PRINT N'SqlProcedure "[AsyncAgent].[Private_AcquireAppLock_GroupAwait]" wird erstellt...';


GO
CREATE PROCEDURE [AsyncAgent].[Private_AcquireAppLock_GroupAwait] (
 @AsyncGroup NVARCHAR(128)
,@LockAcquired INT OUTPUT
,@DelaySec INT = 5
,@DatabaseName NVARCHAR(128) = NULL
,@TimeoutSec INT = -1
)
AS
BEGIN

	-- Proc waits 'non-blocking' for acquiring an exclusive lock on the group.
	-- This can be obtained only if all shared proc locks are released, meaning
	-- that all grouped proc executions are finished.
	-- Why 'non-blocking'?
	-- If a request for an exclusive lock is made and held ('blocking'), no other
	-- shared locks can be acquired. As a result, not all grouped procs might be
	-- already started and neither won't if this proc is called 'too early'.

	SET XACT_ABORT ON;

	IF ISNULL( @DatabaseName, '' ) = ''
		SET @DatabaseName = DB_NAME();

	-- Determining delay between checking job run status
	DECLARE @_DefaultDelaySec SMALLINT = 5;
	DECLARE @_MinDelaySec SMALLINT = 1;
	DECLARE @_MaxDelaySec SMALLINT = 300;
	DECLARE @_DelayString VARCHAR(12);
	DECLARE @_DelayMinutes TINYINT;

	IF @DelaySec IS NULL
		SET @DelaySec = @_DefaultDelaySec;
	IF @DelaySec < @_MinDelaySec
		SET @DelaySec = @_MinDelaySec;
	IF @DelaySec > @_MaxDelaySec
		SET @DelaySec = @_MaxDelaySec;

	IF @DelaySec >= 60
	BEGIN
		SET @_DelayMinutes = @DelaySec / 60;
		SET @DelaySec = @DelaySec % 60;
	END

	SET @_DelayString = 
		CONCAT( '00:0', @_DelayMinutes, ':', RIGHT( '00' + CAST( @DelaySec AS VARCHAR(2) ), 2 ) )
	;

	-- Determining timeout datetime
	DECLARE @_TimeoutDatetime DATETIME;
	IF @TimeoutSec IS NULL
		SEt @TimeoutSec = -1;
	IF @TimeoutSec < -1
		SET @TimeoutSec = ABS( @TimeoutSec ) - 1
	;

	IF @_TimeoutDatetime > -1
		SET @_TimeoutDatetime = DATEADD( SECOND, @TimeoutSec, GETDATE() );
	ELSE
		SET @_TimeoutDatetime = DATETIMEFROMPARTS( 9999, 12, 31, 23, 59, 59, 997 );

	DECLARE @_Msg NVARCHAR(1000);

	DECLARE @_CRLF CHAR(2) = CHAR(13) + CHAR(10);
	DECLARE @_Sql NVARCHAR(4000) =
		N'EXEC @LockAcquired = ' + [AsyncAgent].[QuoteSb_Sysname]( @DatabaseName ) + '..[sp_getapplock]' + @_CRLF +
		N'	 @Resource = @AsyncGroup' + @_CRLF +
		N'	,@LockMode = N''Exclusive''' + @_CRLF +
		N'	,@LockOwner = N''Session''' + @_CRLF +
		N'	,@LockTimeout = 0' + @_CRLF +
		N';'
	;
	DECLARE @_ParamDefinition NVARCHAR(1000) =
		N'@LockAcquired INT OUTPUT, @AsyncGroup NVARCHAR(128)'
	;


	---- ACT
	WHILE ( GETDATE() < @_TimeoutDatetime )
	BEGIN

		WAITFOR DELAY @_DelayString;

		EXEC sp_executesql
			 @stmnt = @_Sql
			,@params = @_ParamDefinition
			,@LockAcquired = @LockAcquired OUTPUT
			,@AsyncGroup = @AsyncGroup
		;

		-- 0: The lock was successfully granted synchronously.
		-- 1: The lock was granted successfully after waiting for other incompatible locks to be released.
		IF @LockAcquired >= 0 -- Group call finished
		BEGIN
			RETURN 0;
		END

		-- -999: Indicates a parameter validation or other call error.
		IF @LockAcquired = -999
		BEGIN
			SET @_Msg = N'Internal error while trying to acquire app lock for async group ''' + @AsyncGroup + '''. Procs in group may still be running!';
			THROW 50011, @_Msg, 0;
		END

		-- Go on waiting for group call to finish
		-- -1: The lock request timed out.
		-- -2: The lock request was canceled.
		-- -3: The lock request was chosen as a deadlock victim.

	END

	SET @_Msg = N'Timeout reached before AsyncGroup ''' + @AsyncGroup + ''' finished executing. Group procs might still be running!';
	THROW 50002, @_Msg, 0;

	RETURN 0;

END
GO
PRINT N'SqlProcedure "[AsyncAgent].[Private_WaitForStartedJob]" wird erstellt...';


GO
CREATE PROCEDURE [AsyncAgent].[Private_WaitForStartedJob] (
 @JobName NVARCHAR(128)
,@DelayMilliseconds SMALLINT = 400
,@TimeoutSec SMALLINT = 300
)
AS
BEGIN

	SET XACT_ABORT ON;

	DECLARE @_DefaultDelay SMALLINT = 400;
	DECLARE @_MinDelay SMALLINT = 100;
	DECLARE @_MaxDelay SMALLINT = 999;
	DECLARE @_DelayString VARCHAR(12);

	DECLARE @_TimeoutDatetime DATETIME;

	-- Determining delay between checking job run status
	IF @DelayMilliseconds IS NULL
		SET @DelayMilliseconds = @_DefaultDelay;
	IF @DelayMilliseconds < @_MinDelay
		SET @DelayMilliseconds = @_MinDelay;
	IF @DelayMilliseconds > @_MaxDelay
		SET @DelayMilliseconds = @_MaxDelay;
	SET @_DelayString =
		CONCAT( '00:00:00.', @DelayMilliseconds );

	-- Determining timeout datetime
	IF @TimeoutSec < 0
		SET @TimeoutSec = ABS( @TimeoutSec ) - 1;
	IF ISNULL( @TimeoutSec, 0 ) = 0
		SET @TimeoutSec = 300;
	SET @_TimeoutDatetime = DATEADD( SECOND, @TimeoutSec, GETDATE() );

	---- VALIDATE
	IF ISNULL( @JobName, '' ) = ''
		THROW 50001 , N'Job name must not be empty!', 0
	;

	---- ACT
	WHILE ( GETDATE() < @_TimeoutDatetime )
	BEGIN

		WAITFOR DELAY @_DelayString;

		IF [AsyncAgent].[IsJobRunning]( @JobName, DEFAULT ) = 1
			RETURN 0;

	END

	DECLARE @_Msg NVARCHAR(1000) = N'Timeout reached before job ''' + @JobName + ''' could be started.';
	THROW 50002, @_Msg, 0;

	RETURN 0;

END
GO
PRINT N'SqlProcedure "[AsyncAgent].[Private_StartJob]" wird erstellt...';


GO
CREATE PROCEDURE [AsyncAgent].[Private_StartJob] (
 @JobName NVARCHAR(128)
)
AS
BEGIN

	SET XACT_ABORT ON;

	---- VALIDATE
	IF ISNULL( @JobName, '' ) = ''
		THROW 50001 , N'Job name must not be empty!', 0
	;

	---- ACT
	EXEC [msdb].[dbo].[sp_start_job]
		 @job_name = @JobName
	;

	RETURN 0;

END
GO
PRINT N'SqlProcedure "[AsyncAgent].[Private_AddAsyncCategoryIfNotExists]" wird erstellt...';


GO
CREATE PROCEDURE [AsyncAgent].[Private_AddAsyncCategoryIfNotExists]
AS
BEGIN

	SET XACT_ABORT ON;

	DECLARE @Category AS TABLE (
		 [category_id] INT
		,[category_type] INT
		,[name] NVARCHAR (128)
	);

	INSERT INTO @Category
	EXEC [msdb].[dbo].[sp_help_category]
	;

	IF NOT EXISTS (
		SELECT TOP 1 [name]
		FROM @Category
		WHERE [name] = 'Async'
	)
		EXEC [msdb].[dbo].[sp_add_category] @class = 'JOB', @type = 'LOCAL', @name = 'Async'
	;

	RETURN 0;

END
GO
PRINT N'SqlProcedure "[AsyncAgent].[Private_AcquireAppLock_Job]" wird erstellt...';


GO
CREATE PROCEDURE [AsyncAgent].[Private_AcquireAppLock_Job] (
 @JobName NVARCHAR(128)
,@LockAcquired INT OUTPUT
,@DatabaseName NVARCHAR(128) = NULL
,@TimeoutMsec INT = 0
)
AS
BEGIN

	SET XACT_ABORT ON;

	IF ISNULL( @DatabaseName, '' ) = ''
		SET @DatabaseName = DB_NAME();

	IF @TimeoutMsec IS NULL
		SET @TimeoutMsec = 0;
	IF @TimeoutMsec < -1
		SET @TimeoutMsec = ABS( @TimeoutMsec ) - 1;

	DECLARE @_CRLF CHAR(2) = CHAR(13) + CHAR(10);
	DECLARE @_Sql NVARCHAR(4000) =
		N'EXEC @LockAcquired = ' + [AsyncAgent].[QuoteSb_Sysname]( @DatabaseName ) + '..[sp_getapplock]' + @_CRLF +
		N'	 @Resource = @JobName' + @_CRLF +
		N'	,@LockMode = N''Exclusive''' + @_CRLF +
		N'	,@LockOwner = N''Session''' + @_CRLF +
		N'	,@LockTimeout = @TimeoutMsec' + @_CRLF +
		N';'
	;
	DECLARE @_ParamDefinition NVARCHAR(1000) =
		N'@LockAcquired INT OUTPUT, @JobName NVARCHAR(128), @TimeoutMsec INT'
	;

	EXEC sp_executesql
		 @stmnt = @_Sql
		,@params = @_ParamDefinition
		,@LockAcquired = @LockAcquired OUTPUT
		,@JobName = @JobName
		,@TimeoutMsec = @TimeoutMsec
	;

	RETURN 0;

END
GO
PRINT N'SqlProcedure "[AsyncAgent].[Private_CreateJob]" wird erstellt...';


GO
CREATE PROCEDURE [AsyncAgent].[Private_CreateJob] (
 @JobName NVARCHAR(128)
,@Description NVARCHAR(512) = N''
,@Force BIT = 0
)
AS
BEGIN

	-- #TODO: Change from recreating (deleting and creating) jobs to updating jobs.
	-- As a result, job history will be retained.

	SET XACT_ABORT ON;

	DECLARE @JobExists BIT = 0;

	---- VALIDATE
	IF ISNULL( @JobName, '' ) = ''
		THROW 50001 , N'Job name must not be empty!', 0
	;

	EXEC [AsyncAgent].[Private_AddAsyncCategoryIfNotExists];

	SELECT TOP 1 @JobExists = 1
	FROM [msdb].[dbo].[sysjobs]
	WHERE [name] = @JobName
	;

	IF @Force = 0 AND @JobExists = 1
		THROW 50002, N'Job already exists. Set parameter ''@Force'' to 1 to overwrite.', 0
	;

	---- ACT
	IF @JobExists = 1
		EXEC [msdb].[dbo].[sp_delete_job] @job_name = @JobName;
	EXEC [msdb].[dbo].[sp_add_job]
		 @job_name = @JobName
		,@description = @Description
		,@category_name = 'Async'
	;

	-- Local job
	EXEC [msdb].[dbo].[sp_add_jobserver] @job_name = @JobName;

	RETURN 0;

END
GO
PRINT N'SqlProcedure "[AsyncAgent].[Private_AcquireAppLock_GroupStart]" wird erstellt...';


GO
CREATE PROCEDURE [AsyncAgent].[Private_AcquireAppLock_GroupStart] (
 @AsyncGroup NVARCHAR(128)
,@LockAcquired INT OUTPUT
,@DatabaseName NVARCHAR(128) = NULL
,@TimeoutMsec INT = 0
)
AS
BEGIN

	SET XACT_ABORT ON;

	IF ISNULL( @DatabaseName, '' ) = ''
		SET @DatabaseName = DB_NAME();

	IF @TimeoutMsec IS NULL
		SET @TimeoutMsec = 0;
	IF @TimeoutMsec < -1
		SET @TimeoutMsec = ABS( @TimeoutMsec ) - 1;

	DECLARE @_CRLF CHAR(2) = CHAR(13) + CHAR(10);
	DECLARE @_Sql NVARCHAR(4000) =
		N'EXEC @LockAcquired = ' + [AsyncAgent].[QuoteSb_Sysname]( @DatabaseName ) + '..[sp_getapplock]' + @_CRLF +
		N'	 @Resource = @AsyncGroup' + @_CRLF +
		N'	,@LockMode = N''Shared''' + @_CRLF +
		N'	,@LockOwner = N''Session''' + @_CRLF +
		N'	,@LockTimeout = @TimeoutMsec' + @_CRLF +
		N';'
	;
	DECLARE @_ParamDefinition NVARCHAR(1000) =
		N'@LockAcquired INT OUTPUT, @AsyncGroup NVARCHAR(128), @TimeoutMsec INT'
	;

	EXEC sp_executesql
		 @stmnt = @_Sql
		,@params = @_ParamDefinition
		,@LockAcquired = @LockAcquired OUTPUT
		,@AsyncGroup = @AsyncGroup
		,@TimeoutMsec = @TimeoutMsec
	;

	RETURN 0;

END
GO
PRINT N'SqlProcedure "[AsyncAgent].[Private_ReleaseAppLock_Group]" wird erstellt...';


GO
CREATE PROCEDURE [AsyncAgent].[Private_ReleaseAppLock_Group] (
 @AsyncGroup NVARCHAR(128)
,@DatabaseName NVARCHAR(128) = NULL
)
AS
BEGIN

	SET XACT_ABORT ON;

	IF ISNULL( @DatabaseName, '' ) = ''
		SET @DatabaseName = DB_NAME();

	DECLARE @_CRLF CHAR(2) = CHAR(13) + CHAR(10);
	DECLARE @_Sql NVARCHAR(4000) =
		N'EXEC ' + [AsyncAgent].[QuoteSb_Sysname]( @DatabaseName ) + '..[sp_releaseapplock]' + @_CRLF +
		N'	 @Resource = @AsyncGroup' + @_CRLF +
		N'	,@LockOwner = N''Session''' + @_CRLF +
		N';'
	;
	DECLARE @_ParamDefinition NVARCHAR(1000) =
		N'@AsyncGroup NVARCHAR(128)'
	;

	EXEC sp_executesql
		 @stmnt = @_Sql
		,@params = @_ParamDefinition
		,@AsyncGroup = @AsyncGroup
	;

	RETURN 0;

END
GO
PRINT N'SqlProcedure "[AsyncAgent].[StartProc]" wird erstellt...';


GO
CREATE PROCEDURE [AsyncAgent].[StartProc] (
 @SchemaName NVARCHAR(130)
,@ProcName NVARCHAR(130)
,@DatabaseName NVARCHAR(130) = NULL
,@AsyncGroup NVARCHAR(128) = NULL
,@TimeoutMsec INT = 0 -- Wait @TimeoutMsec milliseconds for proc call if currently running ( 0 -> Immediate return; -1 -> 'Infinite' waiting )
)
AS
BEGIN

	SET XACT_ABORT ON;

	DECLARE @_FQProcName NVARCHAR(392);
	DECLARE @_FQProcNameHash CHAR(32);
	DECLARE @_Command NVARCHAR(4000); 

	DECLARE @_LockAcquired_Job INT;
	DECLARE @_LockAcquired_Group INT;
	DECLARE @_Msg NVARCHAR(1000);

	EXEC [AsyncAgent].[Private_AssembleCommand]
		 @SchemaName = @SchemaName
		,@ProcName = @ProcName
		,@FQProcName = @_FQProcName OUTPUT
		,@FQProcNameHash = @_FQProcNameHash OUTPUT
		,@Command = @_Command OUTPUT
		,@DatabaseName = @DatabaseName
		,@AsyncGroup = @AsyncGroup
	;

	BEGIN TRY

		-- Grouping of async proc calls is done by shared app locks on
		-- user-defined AsyncGroup identifiers. Waiting for a group to
		-- finish tries to set an exclusive app lock on this identifier.
		-- This is permitted as soon as all shared locks are released.
		IF ISNULL( @AsyncGroup, '' ) > ''
			EXEC [AsyncAgent].[Private_AcquireAppLock_GroupStart]
				 @AsyncGroup = @AsyncGroup
				,@LockAcquired = @_LockAcquired_Group OUTPUT
				,@DatabaseName = @DatabaseName
				,@TimeoutMsec = @TimeoutMsec
		;

		IF @_LockAcquired_Group < 0 
		BEGIN
			SET @_Msg = N'Start lock for AsyncGroup ''' + @AsyncGroup + ''' couldn''t be acquired. Proc hasn''t been executed!';
			THROW 50010, @_Msg, 0;
		END

		-- Job can only be recreated/started if it's not currently running.
		EXEC [AsyncAgent].[Private_AcquireAppLock_Job]
			 @JobName = @_FQProcNameHash
			,@LockAcquired = @_LockAcquired_Job OUTPUT
			,@DatabaseName = @DatabaseName
			,@TimeoutMsec = @TimeoutMsec
		;

		IF @_LockAcquired_Job < 0 
		BEGIN
			SET @_Msg = N'Start lock for proc ''' + @_FQProcName + ''' (job ''' + @_FQProcNameHash + ''') couldn''t be acquired. Proc hasn''t been executed!';
			THROW 50011, @_Msg, 0;
		END

		EXEC [AsyncAgent].[Private_CreateJob] @JobName = @_FQProcNameHash, @Force = 1;
		EXEC [AsyncAgent].[Private_AddTsqlJobStep]
			 @JobName = @_FQProcNameHash
			,@StepName = @_FQProcNameHash
			,@Command = @_Command
			,@ValidateSyntax = 0
		;
		EXEC [AsyncAgent].[Private_StartJob] @JobName = @_FQProcNameHash;

		EXEC [AsyncAgent].[Private_WaitForStartedJob] @JobName = @_FQProcNameHash;
		
	END TRY
	BEGIN CATCH

		-- Locks always have to be released!
		IF @_LockAcquired_Job >= 0
			EXEC [AsyncAgent].[Private_ReleaseAppLock_Job]
				 @JobName = @_FQProcNameHash
				,@DatabaseName = @DatabaseName
		;
		IF @_LockAcquired_Group >= 0
			EXEC [AsyncAgent].[Private_ReleaseAppLock_Group]
				 @AsyncGroup = @AsyncGroup
				,@DatabaseName = @DatabaseName
		;
		THROW;

	END CATCH

	-- Started job will acquire exclusive lock on job and shared lock on group ( if specified ).
	-- After the job has finished, it will release both locks.
	-- A lock that is acquired in this context can't be released by a job!
	IF @_LockAcquired_Job >= 0
		EXEC [AsyncAgent].[Private_ReleaseAppLock_Job]
			 @JobName = @_FQProcNameHash
			,@DatabaseName = @DatabaseName
	;
	IF @_LockAcquired_Group >= 0
		EXEC [AsyncAgent].[Private_ReleaseAppLock_Group]
			 @AsyncGroup = @AsyncGroup
			,@DatabaseName = @DatabaseName
	;

	RETURN 0;

END
GO
PRINT N'SqlProcedure "[AsyncAgent].[AwaitProc]" wird erstellt...';


GO
CREATE PROCEDURE [AsyncAgent].[AwaitProc] (
 @SchemaName NVARCHAR(130)
,@ProcName NVARCHAR(130)
,@DatabaseName NVARCHAR(130) = NULL
,@TimeoutMsec INT = -1 -- Wait @Timeout milliseconds for proc call if currently running ( 0 -> Immediate return; -1 -> 'Infinite' waiting )
)
AS
BEGIN

	SET XACT_ABORT ON;
	
	DECLARE @_FQProcName NVARCHAR(392);
	DECLARE @_FQProcNameHash CHAR(32);
	DECLARE @_Command NVARCHAR(4000); 

	DECLARE @_LockAcquired INT;

	EXEC [AsyncAgent].[Private_AssembleCommand]
		 @SchemaName = @SchemaName
		,@ProcName = @ProcName
		,@FQProcName = @_FQProcName OUTPUT
		,@FQProcNameHash = @_FQProcNameHash OUTPUT
		,@Command = @_Command OUTPUT
		,@DatabaseName = @DatabaseName
	;

	EXEC [AsyncAgent].[Private_AcquireAppLock_Job]
		 @JobName = @_FQProcNameHash
		,@LockAcquired = @_LockAcquired OUTPUT
		,@DatabaseName = @DatabaseName
		,@TimeoutMsec = @TimeoutMsec
	;

	IF @_LockAcquired < 0 
	BEGIN
		DECLARE @_Msg NVARCHAR(1000) =
			N'Await lock for proc ''' + @_FQProcName + ''' (job ''' + @_FQProcNameHash + ''') couldn''t be acquired. Proc might still be executing!';
		THROW 50010, @_Msg, 0;
	END

	EXEC [AsyncAgent].[Private_ReleaseAppLock_Job]
		 @JobName = @_FQProcNameHash
		,@DatabaseName = @DatabaseName
	;
	
	RETURN 0;

END
GO
PRINT N'SqlProcedure "[AsyncAgent].[AwaitGroup]" wird erstellt...';


GO
CREATE PROCEDURE [AsyncAgent].[AwaitGroup] (
 @AsyncGroup NVARCHAR(128)
,@DelaySec INT -- Ask every @DelaySec seconds if group finished executing
,@DatabaseName NVARCHAR(130) = NULL
,@TimeoutSec INT = -1 -- Wait @TimeoutSec seconds for AsyncGroup to finish ( 0 -> Immediate return; -1 -> 'Infinite' waiting )
)
AS
BEGIN

	-- Waits for 

	SET XACT_ABORT ON;
	
	DECLARE @_FQProcName NVARCHAR(392);
	DECLARE @_FQProcNameHash CHAR(32);
	DECLARE @_Command NVARCHAR(4000); 

	DECLARE @_LockAcquired INT;

	EXEC [AsyncAgent].[Private_AcquireAppLock_GroupAwait]
		 @AsyncGroup = @AsyncGroup
		,@DelaySec = @DelaySec
		,@LockAcquired = @_LockAcquired OUTPUT
		,@DatabaseName = @DatabaseName
		,@TimeoutSec = @TimeoutSec
	;

	IF @_LockAcquired >= 0
		EXEC [AsyncAgent].[Private_ReleaseAppLock_Group]
			 @AsyncGroup = @AsyncGroup
			,@DatabaseName = @DatabaseName
		;
	
	RETURN 0;

END
GO

PRINT N'Update abgeschlossen.';


GO
