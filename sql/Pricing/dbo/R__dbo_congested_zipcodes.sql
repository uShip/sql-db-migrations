SET DEADLOCK_PRIORITY LOW
SET LOCK_TIMEOUT 20000

IF
    (
        NOT EXISTS
        (
            SELECT object_id
            FROM sys.objects
            WHERE
                object_id = OBJECT_ID(N'[dbo].[congested_zipcodes]')
                AND type = 'U'
        )
    )
    BEGIN

        CREATE TABLE dbo.congested_zipcodes (
            zipcode [varchar](5) NULL,
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
