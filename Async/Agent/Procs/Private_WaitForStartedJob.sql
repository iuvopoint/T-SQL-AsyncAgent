CREATE PROCEDURE [AsyncAgent].[Private_WaitForStartedJob] (
 @JobName NVARCHAR(128)
,@DelayMilliseconds SMALLINT = 400
,@TimeoutSec SMALLINT = 300
)
AS
BEGIN

	SET XACT_ABORT ON;

	DECLARE @_DefaultDelay SMALLINT = 400;
	DECLARE @_MinDelay SMALLINT = 100;
	DECLARE @_MaxDelay SMALLINT = 999;
	DECLARE @_DelayString VARCHAR(12);

	DECLARE @_TimeoutDatetime DATETIME;

	-- Determining delay between checking job run status
	IF @DelayMilliseconds IS NULL
		SET @DelayMilliseconds = @_DefaultDelay;
	IF @DelayMilliseconds < @_MinDelay
		SET @DelayMilliseconds = @_MinDelay;
	IF @DelayMilliseconds > @_MaxDelay
		SET @DelayMilliseconds = @_MaxDelay;
	SET @_DelayString =
		CONCAT( '00:00:00.', @DelayMilliseconds );

	-- Determining timeout datetime
	IF @TimeoutSec < 0
		SET @TimeoutSec = ABS( @TimeoutSec ) - 1;
	IF ISNULL( @TimeoutSec, 0 ) = 0
		SET @TimeoutSec = 300;
	SET @_TimeoutDatetime = DATEADD( SECOND, @TimeoutSec, GETDATE() );

	---- VALIDATE
	IF ISNULL( @JobName, '' ) = ''
		THROW 50001 , N'Job name must not be empty!', 0
	;

	---- ACT
	WHILE ( GETDATE() < @_TimeoutDatetime )
	BEGIN

		WAITFOR DELAY @_DelayString;

		IF [AsyncAgent].[IsJobRunning]( @JobName, DEFAULT ) = 1
			RETURN 0;

	END

	DECLARE @_Msg NVARCHAR(1000) = N'Timeout reached before job ''' + @JobName + ''' could be started.';
	THROW 50002, @_Msg, 0;

	RETURN 0;

END
