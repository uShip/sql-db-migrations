SET DEADLOCK_PRIORITY LOW
SET LOCK_TIMEOUT 20000

IF
    (
        NOT EXISTS
        (
            SELECT object_id
            FROM sys.objects
            WHERE
                object_id = OBJECT_ID(N'[dbo].[multi_item_markup]')
                AND type = 'U'
        )
    )
    BEGIN
        CREATE TABLE dbo.multi_item_markup (
            totalvolume_min [float] NULL,
            totalvolume_max [float] NULL,
            markup_p [float] NULL,
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
