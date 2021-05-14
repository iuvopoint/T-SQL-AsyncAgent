CREATE PROCEDURE [Bootstrap].[RemoveAsyncAgentCategory]
AS
BEGIN

	DECLARE @Cat SYSNAME = N'Async';

	IF EXISTS (
		SELECT TOP 1 1
		FROM [msdb].[dbo].[syscategories]
		WHERE [name] = @Cat
	)
		EXEC [msdb].[dbo].[sp_delete_category]
			@class = 'JOB', @name = 'Async'
	;

	RETURN 0;

END
