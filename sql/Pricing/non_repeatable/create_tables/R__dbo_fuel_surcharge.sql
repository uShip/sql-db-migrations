SET DEADLOCK_PRIORITY LOW
SET LOCK_TIMEOUT 20000

IF
    (
        NOT EXISTS
        (
            SELECT object_id
            FROM sys.objects
            WHERE
                object_id = OBJECT_ID(N'[dbo].[fuel_surcharge]') AND type = 'U'
        )
    )
    BEGIN

        CREATE TABLE dbo.fuel_surcharge (
            low [float] NULL,
            high [float] NULL,
            fuel_baseline [float] NULL,
            fuel_tiers [float] NULL,
            fuel_surcharge [float] NULL,
            id [int] IDENTITY (1, 1) NOT NULL
        )
    END
