CREATE PROCEDURE [AsyncAgent].[Private_AssembleCommand] (
 @DatabaseName NVARCHAR(130) = NULL
,@SchemaName NVARCHAR(130)
,@ProcName NVARCHAR(130)
,@FQProcName NVARCHAR(392) OUTPUT
,@FQProcNameHash CHAR(32) OUTPUT
,@Command NVARCHAR(4000) OUTPUT
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

	RETURN 0;

END
