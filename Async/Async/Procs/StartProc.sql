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
