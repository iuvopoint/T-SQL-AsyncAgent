CREATE FUNCTION [AsyncAgent].[UnquoteSb_Sysname] (
 @Sysname NVARCHAR(130)
)
RETURNS NVARCHAR(128)
AS
BEGIN

	-- #TODO: Write tests

	-- Returns NULL if @Sysname is NULL, SB unquoted string otherwise.

	IF [AsyncAgent].[isQuotedSb_Sysname]( @Sysname ) = 0
		RETURN @Sysname;

	RETURN SUBSTRING( @Sysname, 2, LEN( @Sysname ) - 2 );

END
