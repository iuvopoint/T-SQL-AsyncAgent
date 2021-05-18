CREATE PROCEDURE [AsyncAgent].[Private_CreateJob] (
 @JobName NVARCHAR(128)
,@Description NVARCHAR(512) = N''
,@Force BIT = 0
)
AS
BEGIN

	-- #TODO: Change from recreating (deleting and creating) jobs to updating jobs.
	-- As a result, job history will be retained.

	SET XACT_ABORT ON;

	DECLARE @JobExists BIT = 0;

	---- VALIDATE
	IF ISNULL( @JobName, '' ) = ''
		THROW 50001 , N'Job name must not be empty!', 0
	;

	EXEC [AsyncAgent].[Private_AddAsyncCategoryIfNotExists];

	SELECT TOP 1 @JobExists = 1
	FROM [msdb].[dbo].[sysjobs]
	WHERE [name] = @JobName
	;

	IF @Force = 0 AND @JobExists = 1
		THROW 50002, N'Job already exists. Set parameter ''@Force'' to 1 to overwrite.', 0
	;

	---- ACT
	IF @JobExists = 1
		EXEC [msdb].[dbo].[sp_delete_job] @job_name = @JobName;
	EXEC [msdb].[dbo].[sp_add_job]
		 @job_name = @JobName
		,@description = @Description
		,@category_name = 'Async'
	;

	-- Local job
	EXEC [msdb].[dbo].[sp_add_jobserver] @job_name = @JobName;

	RETURN 0;

END
