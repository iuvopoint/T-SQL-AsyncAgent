CREATE FUNCTION [AsyncAgent].[GetFQProcNameHash] (
 @DatabaseName NVARCHAR(130) = NULL
,@SchemaName NVARCHAR(130)
,@ProcName NVARCHAR(130)
)
RETURNS CHAR(32)
AS
BEGIN

	-- #TODO: Write tests

	-- Returns MD5 hash of standardized procedure name format. Example:
	-- 'msdb.dbo.SysJobs' returns same hash result as 'msdb.[dbo].sysjobs'

	DECLARE @_FQProcNameHash CHAR(32) = CONVERT( CHAR(32),
		HASHBYTES( 'MD5', UPPER( [AsyncAgent].[GetFQProcName] (
			@DatabaseName, @SchemaName, @ProcName
		) ) ), 2 -- Hex representation without leading '0x'
	);

	RETURN @_FQProcNameHash;
;

END
