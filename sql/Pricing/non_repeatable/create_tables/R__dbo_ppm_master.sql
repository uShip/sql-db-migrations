SET DEADLOCK_PRIORITY LOW
SET LOCK_TIMEOUT 20000

IF
    (
        NOT EXISTS
        (
            SELECT object_id
            FROM sys.objects
            WHERE object_id = OBJECT_ID(N'[dbo].[ppm_master]') AND type = 'U'
        )
    )
    BEGIN

        CREATE TABLE dbo.ppm_master (
            o_msa [nvarchar](150) NULL,
            d_msa [nvarchar](150) NULL,
            ppm [float] NULL,
            id [int] IDENTITY (1, 1) NOT NULL,
            avgmiles [int] NULL,
            minmiles [int] NULL,
            maxmiles [int] NULL,
            listings [int] NULL,
            PRIMARY KEY CLUSTERED
            (
                id ASC
            ) WITH (
                PAD_INDEX = OFF,
                STATISTICS_NORECOMPUTE = OFF,
                IGNORE_DUP_KEY = OFF,
                ALLOW_ROW_LOCKS = ON,
                ALLOW_PAGE_LOCKS = ON
            ) ON [PRIMARY]
        )
    END
