CREATE PROCEDURE [AsyncAgent].[Await] (
 @DatabaseName NVARCHAR(130) = NULL
,@SchemaName NVARCHAR(130)
,@ProcName NVARCHAR(130)
,@Timeout INT = -1 -- Wait @Timeout milliseconds for proc call if currently running ( 0 -> Immediate return; -1 -> 'Infinite' waiting )
)
AS
BEGIN

	SET XACT_ABORT ON;
	
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

	EXEC @LockAcquired = [sp_getapplock]
		 @Resource = @_FQProcNameHash
		,@LockMode = N'Exclusive'
		,@LockOwner = N'Session'
		,@LockTimeout = @Timeout
	;

	DECLARE @_Msg NVARCHAR(1000);
	IF @LockAcquired < 0 
	BEGIN
		SET @_Msg = N'Lock for proc ' + @_FQProcName + ' (' + @_FQProcNameHash + ') couldn''t be acquired. It might still be executing!';
		THROW 50010, @_Msg, 0;
	END

	EXEC [sp_releaseapplock]
		 @Resource = @_FQProcNameHash
		,@LockOwner = N'Session'
	;
	
	RETURN 0;

END
