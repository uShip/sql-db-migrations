SET DEADLOCK_PRIORITY LOW
SET LOCK_TIMEOUT 20000

IF
    (
        NOT EXISTS
        (
            SELECT object_id
            FROM sys.objects
            WHERE object_id = OBJECT_ID(N'[dbo].[state_v6]') AND type = 'U'
        )
    )
    BEGIN

        CREATE TABLE dbo.state_v6 (
            state [varchar](20) NULL,
            minmiles [int] NULL,
            stateo_surcharged [float] NULL,
            stateo_surchargep [float] NULL,
            id [int] IDENTITY (1, 1) NOT NULL
        )
    END
