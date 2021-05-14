CREATE PROCEDURE [AgentTests].[Test New Agent category is correctly created]
AS
BEGIN

	-- Align
	DECLARE @ExpectedCat SYSNAME = N'Async';
	DECLARE @ActualCat NVARCHAR(128);

	-- Act
	EXEC [AsyncAgent].[Private_AddAsyncCategoryIfNotExists];

	SET @ActualCat = (
		SELECT TOP 1 [name]
		FROM [msdb].[dbo].[syscategories]
		WHERE [name] = @ExpectedCat
	);

	-- Assert
	EXEC [tSQLt].[AssertEquals] @Expected = @ExpectedCat, @Actual = @ActualCat;

	RETURN 0;

END
