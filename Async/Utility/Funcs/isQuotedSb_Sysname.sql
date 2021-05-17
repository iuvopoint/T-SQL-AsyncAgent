CREATE FUNCTION [AsyncAgent].[isQuotedSb_Sysname] (
 @Sysname NVARCHAR(130)
)
RETURNS BIT
AS
BEGIN

	-- #TODO: Write tests

	-- Rules for quoted sysname identifiers:
	-- 1. Must be wrapped in square brackets ( '[...]' )
	-- 2. Sysname must not be empty string ( > '' )
	-- 3. May contain '[' and ']' characters inside wrapping square brackets
	-- 4. Only double occurences of character ']' inside wrapping square brackets allowed

	IF @Sysname IS NULL
		RETURN NULL;

	-- Empty strings ( '' ) are not valid sysnames. '[]' is not a valid quoted sysname.
	-- Min length of 3 ( '[?]' ) required for valid quotation.
	IF LEN( @Sysname ) < 3
		RETURN 0;

	-- Not quoted if not wrapped in square brackets.
	IF NOT EXISTS (
		SELECT TOP 1 1
		WHERE @Sysname LIKE '\[%\]' ESCAPE '\'
		)
		RETURN 0
	;

	-- Remove wrapping square brackets.
	SET @Sysname = SUBSTRING( @Sysname, 2, LEN( @Sysname ) - 2 );

	-- Remove every string of even length containing ']' inside @Sysname.
	-- Odd occurences will remain with one particular ']' character and mark
	-- invalid quotation.
	SET @Sysname = REPLACE( @Sysname, ']]', '' );

	-- If there are no single ']' characters remaining, sysname is validly quoted.
	IF CHARINDEX( N']', @Sysname, 0 ) > 0
		RETURN 0;

	RETURN 1;

END
