CREATE PROCEDURE [Async].[Start] (
 @DatabaseName SYSNAME = NULL
,@SchemaName SYSNAME
,@ProcName SYSNAME
)
AS
BEGIN

	SET XACT_ABORT ON;

	DECLARE @Msg NVARCHAR(512);

	---- INIT

	IF @DatabaseName = NULL
		SET @DatabaseName = DB_NAME();
	ELSE IF @DatabaseName NOT IN (
		SELECT [name]
		FROM [sys].[databases]
	)
		SET @Msg = N'Database ' + @DatabaseName + ' doesn''t exist.' ;
		THROW 50001, @Msg, 0
	;

	-- TODO: Doesn't support secure quotation yet! Implement by chance.
	DECLARE @_FQProcName NVARCHAR(261) = @SchemaName + @ProcName;


	---- VALIDATE 

	-- NULL check to pure procedure qualifier.
	IF @_FQProcName IS NULL
		THROW 50001, N'Schema or proc name must not be NULL.', 0
	;

	-- Add DB context to procedure qualifier.
	SET @_FQProcName = @DatabaseName + @_FQProcName;

	IF OBJECT_ID( @_FQProcName ) IS NULL
		SET @Msg = N'Unknown procedure: ' + @_FQProcName;
		THROW 50002, @Msg, 0
	;

	---- ACT

	-- Create Job
	-- TODO

	-- Start Job
	-- TODO

	RETURN 0;

END
