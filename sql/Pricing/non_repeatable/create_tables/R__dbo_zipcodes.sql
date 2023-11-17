SET DEADLOCK_PRIORITY LOW
SET LOCK_TIMEOUT 20000

IF
    (
        NOT EXISTS
        (
            SELECT object_id
            FROM sys.objects
            WHERE object_id = OBJECT_ID(N'[dbo].[congested_v6]') AND type = 'U'
        )
    )
    BEGIN

        CREATE TABLE dbo.zipcodes (
            zipcode [char](5) NOT NULL,
            latitude [decimal](12, 6) NULL,
            longitude [decimal](12, 6) NULL,
            state [char](2) NULL,
            statefullname [varchar](35) NULL,
            areacode [varchar](55) NULL,
            city [varchar](35) NULL,
            msa_name [varchar](150) NULL,
            cbsa_name [varchar](150) NULL,
            pmsa_name [varchar](150) NULL,
            region [varchar](10) NULL,
            division [varchar](20) NULL,
            id [int] IDENTITY (1, 1) NOT NULL,
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
