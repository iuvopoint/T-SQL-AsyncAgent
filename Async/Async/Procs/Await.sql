CREATE PROCEDURE [AsyncAgent].[Await] (
 @DatabaseName NVARCHAR(130) = NULL
,@SchemaName NVARCHAR(130)
,@ProcName NVARCHAR(130)
,@TimeoutMsec INT = -1 -- Wait @Timeout milliseconds for proc call if currently running ( 0 -> Immediate return; -1 -> 'Infinite' waiting )
)
AS
BEGIN

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

	EXEC [AsyncAgent].[Private_AcquireJobAppLock]
		 @JobName = @_FQProcNameHash
		,@LockAcquired = @_LockAcquired OUTPUT
		,@DatabaseName = @DatabaseName
		,@TimeoutMsec = @TimeoutMsec
	;

	IF @_LockAcquired < 0 
	BEGIN
		DECLARE @_Msg NVARCHAR(1000) =
			N'Await lock for proc ''' + @_FQProcName + ''' (job ''' + @_FQProcNameHash + ''') couldn''t be acquired. Proc might still be executing!';
		THROW 50010, @_Msg, 0;
	END

	EXEC [AsyncAgent].[Private_ReleaseJobAppLock]
		 @JobName = @_FQProcNameHash
		,@DatabaseName = @DatabaseName
	;
	
	RETURN 0;

END
