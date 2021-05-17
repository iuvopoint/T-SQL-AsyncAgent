CREATE PROCEDURE [AsyncAgent].[Start] (
 @DatabaseName NVARCHAR(130) = NULL
,@SchemaName NVARCHAR(130)
,@ProcName NVARCHAR(130)
,@Timeout INT = 0 -- Wait @Timeout milliseconds for proc call if currently running ( 0 -> Immediate return; -1 -> 'Infinite' waiting )
)
AS
BEGIN

	SET XACT_ABORT ON;

	IF @Timeout IS NULL
		SET @Timeout = 0;
	IF @Timeout < -1
		SET @Timeout = ABS( @Timeout );
		

	DECLARE @_FQProcName NVARCHAR(392);
	DECLARE @_FQProcNameHash CHAR(32);
	DECLARE @_Command NVARCHAR(4000); 

	DECLARE @LockAcquired INT;

	EXEC [AsyncAgent].[Private_AssembleCommand]
		 @DatabaseName = @DatabaseName
		,@SchemaName = @SchemaName
		,@ProcName = @ProcName
		,@FQProcName = @_FQProcName OUTPUT
		,@FQProcNameHash = @_FQProcNameHash OUTPUT
		,@Command = @_Command OUTPUT
	;

	-- Job can only be recreated/started if it's not currently running.
	EXEC @LockAcquired = [sp_getapplock]
		 @Resource = @_FQProcNameHash
		,@LockMode = N'Exclusive'
		,@LockOwner = N'Session'
		,@LockTimeout = @Timeout
	;

	DECLARE @_Msg NVARCHAR(1000);
	IF @LockAcquired < 0 
	BEGIN
		SET @_Msg = N'Lock for proc ' + @_FQProcName + ' (' + @_FQProcNameHash + ') couldn''t be acquired. It hasn''t been started!';
		THROW 50010, @_Msg, 0;
	END

	BEGIN TRY

		EXEC [AsyncAgent].[Private_CreateJob] @JobName = @_FQProcNameHash, @Force = 1;
		EXEC [AsyncAgent].[Private_AddTsqlJobStep]
			 @JobName = @_FQProcNameHash
			,@StepName = @_FQProcNameHash
			,@Command = @_Command
			,@ValidateSyntax = 0
		;
		EXEC [AsyncAgent].[Private_StartJob] @JobName = @_FQProcNameHash;

		WAITFOR DELAY N'00:00:01';
		
	END TRY
	BEGIN CATCH
	END CATCH

	-- In every case - even if something went wrong - lock has to be released.
	-- Started job will then acquire an exclusive lock and release after execution.
	-- A lock that is acquired in this context can't be released by a job!
	EXEC [sp_releaseapplock]
		 @Resource = @_FQProcNameHash
		,@LockOwner = N'Session'
	;

	RETURN 0;

END
