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
