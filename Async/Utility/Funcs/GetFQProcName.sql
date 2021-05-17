CREATE FUNCTION [AsyncAgent].[GetFQProcName] (
 @DatabaseName NVARCHAR(130) = NULL
,@SchemaName NVARCHAR(130)
,@ProcName NVARCHAR(130)
)
RETURNS NVARCHAR(392)
AS
BEGIN

	-- #TODO: Write tests

	IF ISNULL( @DatabaseName, '' ) = ''
		SET @DatabaseName = DB_NAME();

	DECLARE @_FQProcName NVARCHAR(392) = 
		[AsyncAgent].[QuoteSb_Sysname]( @DatabaseName ) + '.' +
		[AsyncAgent].[QuoteSb_Sysname]( @SchemaName ) + '.' +
		[AsyncAgent].[QuoteSb_Sysname]( @ProcName )
	;

	IF OBJECT_ID( @_FQProcName ) IS NULL
		RETURN NULL;

	RETURN @_FQProcName;

END
