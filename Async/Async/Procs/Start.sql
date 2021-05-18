CREATE PROCEDURE [AsyncAgent].[Start] (
 @DatabaseName NVARCHAR(130) = NULL
,@SchemaName NVARCHAR(130)
,@ProcName NVARCHAR(130)
,@TimeoutMsec INT = 0 -- Wait @TimeoutMsec milliseconds for proc call if currently running ( 0 -> Immediate return; -1 -> 'Infinite' waiting )
)
AS
BEGIN

	-- #TODO: Add job groups
	-- - This proc
	--   - Parameter
	--   - Shared lock on group name resource
	-- - New proc [AsyncAgent].[AwaitGroup]
	--   - Exclusive lock on group name resource 
	--   - Parameter for 'blocking' or 'non-blocking' waiting
	--      - 'blocking': no further shared lock can be acquired while waiting
	--      - 'non-blocking': further shared locks can be acquired while waiting
	-- - Think about 'handing over' group locks safely from start proc to agent job

	SET XACT_ABORT ON;

	DECLARE @_FQProcName NVARCHAR(392);
	DECLARE @_FQProcNameHash CHAR(32);
	DECLARE @_Command NVARCHAR(4000); 

	DECLARE @_LockAcquired INT;

	EXEC [AsyncAgent].[Private_AssembleCommand]
		 @DatabaseName = @DatabaseName
		,@SchemaName = @SchemaName
		,@ProcName = @ProcName
		,@FQProcName = @_FQProcName OUTPUT
		,@FQProcNameHash = @_FQProcNameHash OUTPUT
		,@Command = @_Command OUTPUT
	;

	-- Job can only be recreated/started if it's not currently running.
	EXEC [AsyncAgent].[Private_AcquireJobAppLock]
		 @JobName = @_FQProcNameHash
		,@LockAcquired = @_LockAcquired OUTPUT
		,@DatabaseName = @DatabaseName
		,@TimeoutMsec = @TimeoutMsec
	;

	IF @_LockAcquired < 0 
	BEGIN
		DECLARE @_Msg NVARCHAR(1000) =
			N'Start lock for proc ''' + @_FQProcName + ''' (job ''' + @_FQProcNameHash + ''') couldn''t be acquired. Proc hasn''t been executed!';
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

		EXEC [AsyncAgent].[Private_WaitForStartedJob] @JobName = @_FQProcNameHash;
		
	END TRY
	BEGIN CATCH

		-- In every case - even if something went wrong - lock has to be released.
		EXEC [AsyncAgent].[Private_ReleaseJobAppLock]
			 @JobName = @_FQProcNameHash
			,@DatabaseName = @DatabaseName
		;
		THROW;

	END CATCH

	-- Started job will acquire an exclusive lock and release after execution.
	-- A lock that is acquired in this context can't be released by a job!
	EXEC [AsyncAgent].[Private_ReleaseJobAppLock]
		 @JobName = @_FQProcNameHash
		,@DatabaseName = @DatabaseName
	;

	RETURN 0;

END
