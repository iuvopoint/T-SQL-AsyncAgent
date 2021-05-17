CREATE PROCEDURE [Async].[Start] (
 @DatabaseName NVARCHAR(130) = NULL
,@SchemaName NVARCHAR(130)
,@ProcName NVARCHAR(130)
)
AS
BEGIN

	SET XACT_ABORT ON;

	IF ISNULL( @DatabaseName, '' ) = ''
		SET @DatabaseName = DB_NAME();

	DECLARE @_FQProcName NVARCHAR(392) = [AsyncAgent].[GetFQProcName] (
		@DatabaseName, @SchemaName, @ProcName )
	;
	DECLARE @_FQProcNameHash CHAR(32) = [AsyncAgent].[GetFQProcNameHash] (
		@DatabaseName, @SchemaName, @ProcName )
	;

	DECLARE @_Msg NVARCHAR(1000);


	---- VALIDATE 
	-- DB_ID does not work for quoted input ( e.g. DB_ID( N'master' ) -> 1; DB_ID( N'[master]' ) -> NULL ).
	SET @DatabaseName = [AsyncAgent].[UnquoteSb_Sysname]( @DatabaseName );
	IF DB_ID( @DatabaseName ) IS NULL
	BEGIN
		SET @_Msg = N'Database ''' + @DatabaseName + ''' doesn''t exist! Check your input please.';
		THROW 50001, @_Msg, 0
	END

	-- OBJECT_ID does work with quoted sysnames however...
	IF OBJECT_ID( @_FQProcName ) IS NULL
	BEGIN
		SET @_Msg = N'Unknown procedure: ' + @_FQProcName + '. Check your input please.';
		THROW 50002, @_Msg, 0
	END
	;


	---- ACT
	SET @_FQProcName = N'EXEC ' + @_FQProcName + ';';
	EXEC [AsyncAgent].[Private_CreateJob] @JobName = @_FQProcNameHash, @Force = 1;
	EXEC [AsyncAgent].[Private_AddTsqlJobStep]
		 @JobName = @_FQProcNameHash
		,@StepName = @_FQProcNameHash
		,@Command = @_FQProcName
		,@ValidateSyntax = 0
	;
	EXEC [AsyncAgent].[Private_StartJob] @JobName = @_FQProcNameHash;


	RETURN 0;

END
