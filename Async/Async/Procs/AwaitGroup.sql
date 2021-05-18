CREATE PROCEDURE [AsyncAgent].[AwaitGroup] (
 @AsyncGroup NVARCHAR(128)
,@DelaySec INT -- Ask every @DelaySec if group finished executing
,@DatabaseName NVARCHAR(130) = NULL
,@TimeoutSec INT = -1 -- Wait @TimeoutSec seconds for AsyncGroup to finish ( 0 -> Immediate return; -1 -> 'Infinite' waiting )
)
AS
BEGIN

	-- Waits for 

	SET XACT_ABORT ON;
	
	DECLARE @_FQProcName NVARCHAR(392);
	DECLARE @_FQProcNameHash CHAR(32);
	DECLARE @_Command NVARCHAR(4000); 

	DECLARE @_LockAcquired INT;

	EXEC [AsyncAgent].[Private_AcquireAppLock_GroupAwait]
		 @AsyncGroup = @AsyncGroup
		,@DelaySec = @DelaySec
		,@LockAcquired = @_LockAcquired OUTPUT
		,@DatabaseName = @DatabaseName
		,@TimeoutSec = @TimeoutSec
	;

	IF @_LockAcquired < 0 
	BEGIN
		DECLARE @_Msg NVARCHAR(1000) =
			N'Await lock for AsyncGroup ''' + @AsyncGroup + ''' couldn''t be acquired. Group procs might still be executing!';
		THROW 50011, @_Msg, 0;
	END

	EXEC [AsyncAgent].[Private_ReleaseAppLock_Group]
		 @AsyncGroup = @AsyncGroup
		,@DatabaseName = @DatabaseName
	;
	
	RETURN 0;

END
