SET DEADLOCK_PRIORITY LOW
SET LOCK_TIMEOUT 20000

IF
    (
        NOT EXISTS
        (
            SELECT object_id
            FROM sys.objects
            WHERE
                object_id = OBJECT_ID(N'[dbo].[furniture_indexes]')
                AND type = 'U'
        )
    )
    BEGIN
        CREATE TABLE dbo.furniture_indexes (
            keyword [nvarchar](100) NULL,
            difficulty_idx [float] NULL,
            fragile_idx [float] NULL,
            singleitemqty [float] NULL,
            addtl_percent [float] NULL,
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
