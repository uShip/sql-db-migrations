SET DEADLOCK_PRIORITY LOW
SET LOCK_TIMEOUT 20000

IF
    (
        NOT EXISTS
        (
            SELECT object_id
            FROM sys.objects
            WHERE object_id = OBJECT_ID(N'[dbo].[dmsa_surcharge]') AND type = 'U'
        )
    )
    BEGIN

        CREATE TABLE dbo.dmsa_surcharge (
            msa [nvarchar](100) NULL,
            surchargep [float] NULL,
            surcharged [float] NULL
        )
    END
