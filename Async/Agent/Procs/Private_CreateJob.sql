CREATE PROCEDURE [AsyncAgent].[Private_CreateJob] (
 @JobName NVARCHAR(128)
,@Description NVARCHAR(512)
,@Force BIT = 0
)
AS
BEGIN

	SET XACT_ABORT ON;

	---- VALIDATE
	IF ISNULL( @JobName, '' ) = ''
		THROW 50001 , N'Job name must not be empty!', 0
	;

	EXEC [AsyncAgent].[Private_AddAsyncCategoryIfExists];

	IF @Force = 0 AND EXISTS (
		SELECT TOP 1 1
		FROM [msdb].[dbo].[sysjobs]
		WHERE [name] = @JobName
	)
		THROW 50002, N'Job already exists. Set parameter ''@Force'' to 1 to overwrite.', 0
	;

	EXEC [msdb].[dbo].[sp_add_job]
		 @job_name = @JobName
		,@description = @Description
		,@category_name = 'Async'
	;

	RETURN 0;

END
