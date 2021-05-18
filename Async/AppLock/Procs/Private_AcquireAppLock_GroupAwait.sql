CREATE PROCEDURE [AsyncAgent].[Private_AcquireAppLock_GroupAwait] (
 @AsyncGroup NVARCHAR(128)
,@DelaySec INT
,@LockAcquired INT OUTPUT
,@DatabaseName NVARCHAR(128) = NULL
,@TimeoutSec INT = -1
)
AS
BEGIN

	-- Proc waits 'non-blocking' for an exclusive lock on the group.
	-- This can be obtained only if all shared proc locks are released, meaning
	-- that all grouped proc executions are finished.
	-- Why 'non-blocking'?
	-- If a request for an exclusive lock is made and held ('blocking'), no other
	-- shared locks can be acquired. As a result, not all grouped procs might be
	-- already started and neither won't if the this proc is called 'too early'.

	-- #TODO: Develop this!

	SET XACT_ABORT ON;

	IF ISNULL( @DatabaseName, '' ) = ''
		SET @DatabaseName = DB_NAME();

	DECLARE @_DefaultDelay SMALLINT = 400;
	DECLARE @_MinDelay SMALLINT = 50;
	DECLARE @_MaxDelay SMALLINT = 999;
	DECLARE @_DelayString VARCHAR(12);

	DECLARE @_TimeoutDatetime DATETIME;

	THROW 50100, N'Not implemented exception for [AsyncAgent].[Private_AcquireAppLock_GroupAwait]!', 0;

	/*
	IF @TimeoutMsec IS NULL
		SET @TimeoutMsec = 0;
	IF @TimeoutMsec < -1
		SET @TimeoutMsec = ABS( @TimeoutMsec ) - 1;


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
		N'@LockAcquired INT OUTPUT, @AsyncGroup NVARCHAR(128), @TimeoutMsec INT'
	;

	EXEC sp_executesql
		 @stmnt = @_Sql
		,@params = @_ParamDefinition
		,@LockAcquired = @LockAcquired OUTPUT
		,@AsyncGroup = @AsyncGroup
		,@TimeoutMsec = @TimeoutMsec
	;
	*/

	RETURN 0;

END
