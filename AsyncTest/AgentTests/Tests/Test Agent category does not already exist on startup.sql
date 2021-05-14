CREATE PROCEDURE [AgentTests].[Test Agent category does not already exist on startup]
AS
BEGIN

	-- Align
	DECLARE @ExpectedCat NVARCHAR(128) = NULL;
	DECLARE @ActualCat NVARCHAR(128) = NULL;

	-- Act
	SET @ActualCat = (
		SELECT TOP 1 [name]
		FROM [msdb].[dbo].[syscategories]
		WHERE [name] = N'Async'
	);

	-- Assert
	EXEC [tSQLt].[AssertEquals] @Expected = @ExpectedCat, @Actual = @ActualCat;

	RETURN 0;

END
