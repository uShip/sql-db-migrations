SET DEADLOCK_PRIORITY LOW
SET LOCK_TIMEOUT 20000

IF
    (
        NOT EXISTS (
            SELECT object_id
            FROM sys.objects
            WHERE object_id = OBJECT_ID(N'[dbo].[USHIPCOMMERCE_PARTNERS]') AND type = 'U'
            )
    )
    BEGIN

        CREATE TABLE dbo.USHIPCOMMERCE_PARTNERS (
            USERID VARCHAR(75),
            USERNAME VARCHAR(50),
            NAME VARCHAR(1000),
            PRIMARYCONTACTUSERNAME VARCHAR(200),
            ACTIVE NUMERIC(1,0),
            AM VARCHAR(MAX),
            AM_NAME VARCHAR(1000),
            AE VARCHAR(100),
            AE_NAME VARCHAR(121),
            STRATEGICPARTNER NUMERIC(1,0),
            STARTDATE DATETIME2, -- Changed from TIMESTAMP_NTZ
            ENDDATE DATETIME2, -- Changed from TIMESTAMP_NTZ
            SHOPIFY NUMERIC(1,0),
            PILOTSTARTDATE DATETIME2, -- Changed from TIMESTAMP_NTZ
            PILOTENDDATE DATETIME2, -- Changed from TIMESTAMP_NTZ
            CLOSEDATE DATETIME2, -- Changed from TIMESTAMP_NTZ
            STAGE VARCHAR(40),
            ACCOUNTNAME VARCHAR(1000),
            "StartDate(SkippedPilot)" DATETIME2, -- Changed from TIMESTAMP_NTZ
            SPMUSHIPEXPECTEDVOLUME FLOAT,
            USHIPEXPECTEDREVENUEANNUAL VARCHAR(100),
            ECOMMERCEPLATFORM VARCHAR(1000),
            MONTHLYRECURRINGREVENUE VARCHAR(100),
            SPMPILOTVOLUME FLOAT,
            USHIPEXPECTEDPILOTREVENUE VARCHAR(100),
            PILOTDURATIONMONTHS NUMERIC(18,0),
            PILOTDURATIONDAYS NUMERIC(9,0),
            MONTHLYUSHIPEXPECTEDPILOTREVENUE FLOAT,
            INVOICEDATE DATETIME2, -- Changed from TIMESTAMP_NTZ
            ANNUALFEE VARCHAR(100)
        )
    END
