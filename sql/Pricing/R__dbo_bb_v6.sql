SET DEADLOCK_PRIORITY LOW 
SET LOCK_TIMEOUT 20000

BEGIN TRAN 
CREATE OR ALTER TABLE dbo.bb_v6(
	[bb_rating] [int] NOT NULL,
	[bb_surchargeD] [float] NULL,
	[bb_surchargeP] [float] NULL 
) ON [PRIMARY]


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
                )
				
				
	COMMIT;
