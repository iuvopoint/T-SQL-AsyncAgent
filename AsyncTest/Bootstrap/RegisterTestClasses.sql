CREATE PROCEDURE [Bootstrap].[RegisterTestClasses]
AS
BEGIN

	DECLARE @Class NVARCHAR(128) = N'';
	DECLARE @SqlCommand NVARCHAR(1000) = N'';

	WHILE 1 = 1 -- per test class schema
	BEGIN

		SET @Class = (
			SELECT TOP 1 [name]
			FROM [sys].[schemas]
			WHERE
				    [name] LIKE N'%Tests'
				AND [name] > @Class
			ORDER BY [name]
		);

		IF @Class IS NULL
			BREAK;

		-- Use internal tSQLt with caution!
		-- Due to DB always recreating deployment process, regular NewTestClass-Proc cannot be used.
		SET @SqlCommand = N'EXEC [tSQLt].[Private_MarkSchemaAsTestClass] @QuotedClassName = N''[' + @Class + N']'';';
		EXEC sp_executesql @SqlCommand;

	END -- WHILE per test class schema

	RETURN 0;

END
