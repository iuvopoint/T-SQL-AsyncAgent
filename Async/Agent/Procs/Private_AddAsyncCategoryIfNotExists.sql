CREATE PROCEDURE [AsyncAgent].[Private_AddAsyncCategoryIfNotExists]
AS
BEGIN

	SET XACT_ABORT ON;

	DECLARE @Category AS TABLE (
		 [category_id] INT
		,[category_type] INT
		,[name] NVARCHAR (128)
	);

	INSERT INTO @Category
	EXEC [msdb].[dbo].[sp_help_category]
	;

	IF NOT EXISTS (
		SELECT TOP 1 [name]
		FROM @Category
		WHERE [name] = 'Async'
	)
		EXEC [msdb].[dbo].[sp_add_category] @class = 'JOB', @type = 'LOCAL', @name = 'Async'
	;

	RETURN 0;

END
