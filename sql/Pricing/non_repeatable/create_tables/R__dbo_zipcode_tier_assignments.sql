SET DEADLOCK_PRIORITY LOW
SET LOCK_TIMEOUT 20000

IF
    (
        NOT EXISTS
        (
            SELECT object_id
            FROM sys.objects
            WHERE
                object_id = OBJECT_ID(N'[dbo].[zipcode_tier_assignments]')
                AND type = 'U'
        )
    )
    BEGIN

        CREATE TABLE dbo.zipcode_tier_assignments (
            zip [nvarchar](20) NULL,
            otier [nvarchar](2) NULL,
            dtier [nvarchar](2) NULL
        )
    END
