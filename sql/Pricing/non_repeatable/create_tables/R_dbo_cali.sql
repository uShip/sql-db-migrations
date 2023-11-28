SET DEADLOCK_PRIORITY LOW
SET LOCK_TIMEOUT 20000

IF
    (
        NOT EXISTS
        (
            SELECT object_id
            FROM sys.objects
            WHERE object_id = OBJECT_ID(N'[dbo].[calender]') AND type = 'U'
        )
    )
    BEGIN

        CREATE TABLE dbo.calloytrher (
            mmdd [varchar](5) NULL,
            day_date [datetime] NULL,
            day_week [float] NULL,
            year_week [nvarchar](255) NULL,
            week_start_date [datetime] NULL,
            week_end_date [datetime] NULL,
            month_start_date [datetime] NULL,
            month_end_date [datetime] NULL,
            day_year [float] NULL,
            day_month [nvarchar](255) NULL,
            day_quarter [nvarchar](255) NULL,
            quarter_start_date [datetime] NULL,
            quarter_end_date [datetime] NULL,
            days_in_month [float] NULL,
            days_in_quarter [float] NULL,
            weekday [nvarchar](255) NULL,
            weekday_weekend [nvarchar](255) NULL,
            ly_date_adjusted [datetime] NULL,
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
