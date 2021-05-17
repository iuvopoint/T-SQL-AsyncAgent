CREATE PROCEDURE [AsyncAgent].[Private_StartJob] (
 @JobName NVARCHAR(128)
)
AS
BEGIN

	SET XACT_ABORT ON;

	---- VALIDATE
	IF ISNULL( @JobName, '' ) = ''
		THROW 50001 , N'Job name must not be empty!', 0
	;

	---- ACT
	EXEC [msdb].[dbo].[sp_start_job]
		 @job_name = @JobName
	;

	RETURN 0;

END
