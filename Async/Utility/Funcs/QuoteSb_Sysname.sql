CREATE FUNCTION [AsyncAgent].[QuoteSb_Sysname] (
 @Sysname NVARCHAR(128)
)
RETURNS NVARCHAR(130)
AS
BEGIN

	-- Returns NULL if @Sysname is NULL, SB quoted string otherwise.

	IF [AsyncAgent].[IsQuotedSb_Sysname]( @Sysname ) = 0
		RETURN QUOTENAME( @Sysname );

	RETURN @Sysname;

END
