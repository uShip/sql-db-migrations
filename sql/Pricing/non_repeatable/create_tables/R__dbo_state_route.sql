SET DEADLOCK_PRIORITY LOW
SET LOCK_TIMEOUT 20000

IF
    (
        NOT EXISTS
        (
            SELECT object_id
            FROM sys.objects
            WHERE object_id = OBJECT_ID(N'[dbo].[state_route]') AND type = 'U'
        )
    )
    BEGIN

        CREATE TABLE dbo.state_route (
            o_st [nvarchar](2) NULL,
            d_st [nvarchar](2) NULL,
            surchargep [float] NULL,
            surcharged [float] NULL
        )
    END
