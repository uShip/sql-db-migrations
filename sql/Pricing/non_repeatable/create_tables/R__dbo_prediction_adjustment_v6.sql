SET DEADLOCK_PRIORITY LOW
SET LOCK_TIMEOUT 20000

IF
    (
        NOT EXISTS
        (
            SELECT object_id
            FROM sys.objects
            WHERE
                object_id = OBJECT_ID(N'[dbo].[prediction_adjustment_v6]')
                AND type = 'U'
        )
    )
    BEGIN

        CREATE TABLE dbo.prediction_adjustment_v6 (
            adjustment_easy [float] NULL,
            adjustment_noteasy [float] NULL
        )

    END
