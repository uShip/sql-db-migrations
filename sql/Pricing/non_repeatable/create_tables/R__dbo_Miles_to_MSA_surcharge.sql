SET DEADLOCK_PRIORITY LOW
SET LOCK_TIMEOUT 20000

IF
    (
        NOT EXISTS
        (
            SELECT object_id
            FROM sys.objects
            WHERE
                object_id = OBJECT_ID(N'[dbo].[Miles_to_MSA_surcharge]')
                AND type = 'U'
        )
    )
    BEGIN

        CREATE TABLE dbo.miles_to_msa_surcharge (
            minmiles [float] NULL,
            maxmiles [float] NULL,
            surcharged [float] NULL
        )
    END
