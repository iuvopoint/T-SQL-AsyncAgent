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
