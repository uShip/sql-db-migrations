SET DEADLOCK_PRIORITY LOW
SET LOCK_TIMEOUT 20000

IF
    (
        NOT EXISTS
        (
            SELECT object_id
            FROM sys.objects
            WHERE object_id = OBJECT_ID(N'[dbo].[bb_v6]') AND type = 'U'
        )
    )
    BEGIN

        CREATE TABLE dbo.bb_v6 (
            bb_rating [int] NOT NULL,
            bb_surcharged [float] NULL,
            bb_surchargep [float] NULL,
            datecreatedutc datetime2 NOT NULL CONSTRAINT df_bigandbulkysurcharge_datecreated DEFAULT (
                SYSUTCDATETIME()
            ),
            dateupdatedutc datetime2 NOT NULL CONSTRAINT df_bigandbulkysurcharge_dateupdated DEFAULT (
                SYSUTCDATETIME()
            )
        ) ON [PRIMARY]

    END

CREATE TABLE #bb_v6_insert (
    bb_rating int, bb_surcharged float, bb_surchargep float
)
INSERT INTO #bb_v6_insert (bb_rating, bb_surcharged, bb_surchargep)
VALUES (0, 0, 0),
(1, 0, 0.1),
(2, 0, 0.18)

MERGE dbo.bb_v6 AS b
USING #bb_v6_insert AS i
    ON i.bb_rating = b.bb_rating
WHEN MATCHED
    THEN
    UPDATE
        SET
            b.bb_surcharged = i.bb_surcharged,
            b.bb_surchargep = i.bb_surchargep,
            b.dateupdatedutc = SYSUTCDATETIME()
WHEN NOT MATCHED
    THEN
    INSERT (
        bb_rating,
        bb_surcharged,
        bb_surchargep
    )
    VALUES (
        i.bb_rating,
        i.bb_surcharged,
        i.bb_surchargep
    );
