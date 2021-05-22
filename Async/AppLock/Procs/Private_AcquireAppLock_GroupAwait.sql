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
