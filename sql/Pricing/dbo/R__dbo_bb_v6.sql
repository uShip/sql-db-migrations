SET DEADLOCK_PRIORITY LOW 
SET LOCK_TIMEOUT 20000

IF 
 ( NOT EXISTS 
   (select object_id from sys.objects where object_id = OBJECT_ID(N'[dbo].[bb_v6]') and type = 'U')
 )
BEGIN

CREATE TABLE dbo.bb_v6(
	[bb_rating] [int] NOT NULL,
	[bb_surchargeD] [float] NULL,
	[bb_surchargeP] [float] NULL, 
	[DateCreatedUTC] datetime2 NOT NULL CONSTRAINT [DF_BigAndBulkySurcharge_DateCreated]  DEFAULT (sysutcdatetime()) FOR [DateCreatedUTC],
	[DateUpdatedUTC] datetime2 NOT NULL CONSTRAINT [DF_BigAndBulkySurcharge_DateCreated]  DEFAULT (sysutcdatetime()) FOR [DateCreatedUTC]
) ON [PRIMARY]

END

CREATE TABLE #bb_v6_insert ([bb_rating] int, [bb_surchargeD] float, [bb_surchargeP] float) 
INSERT INTO #bb_v6_insert ([bb_rating], [bb_surchargeD], [bb_surchargeP]) 
VALUES  (0, 0, 0),
		(1, 0, 0.1),
		(2, 0, 0.18)

MERGE dbo.bb_v6 AS b
	USING #bb_v6_insert AS i
	ON i.bb_rating = b.bb_rating
	WHEN MATCHED THEN
	  UPDATE SET 
            b.bb_surchargeD=i.bb_surchargeD,
            b.bb_surchargeP=i.bb_surchargeP
			b.DateUpdatedUTC=sysutcdatetime()
	WHEN NOT MATCHED THEN
	  INSERT (
            bb_rating,
            bb_surchargeD,
            bb_surchargeP
            )  
		VALUES (
                i.bb_rating,
                i.bb_surchargeD,
                i.bb_surchargeP
                );