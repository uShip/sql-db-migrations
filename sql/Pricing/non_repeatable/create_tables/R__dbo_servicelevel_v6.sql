SET DEADLOCK_PRIORITY LOW
SET LOCK_TIMEOUT 20000

IF
    (
        NOT EXISTS
        (
            SELECT object_id
            FROM sys.objects
            WHERE
                object_id = OBJECT_ID(N'[dbo].[servicelevel_v6]') AND type = 'U'
        )
    )
    BEGIN

        CREATE TABLE dbo.servicelevel_v6 (
            partner [varchar](50) NULL,
            sl_surchargep [float] NULL,
            id [int] IDENTITY (1, 1) NOT NULL
        )
    END
