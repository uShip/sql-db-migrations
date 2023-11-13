SET DEADLOCK_PRIORITY LOW
SET LOCK_TIMEOUT 20000

IF
    (
        NOT EXISTS
        (
            SELECT object_id
            FROM sys.objects
            WHERE
                object_id = OBJECT_ID(N'[dbo].[MSA_to_MSA_Rates_by_Mileage]')
                AND type = 'U'
        )
    )
    BEGIN

        CREATE TABLE dbo.msa_to_msa_rates_by_mileage (
            omsa [nvarchar](100) NULL,
            dmsa [nvarchar](100) NULL,
            maxmiles [int] NULL,
            rate [float] NULL
        )
    END
