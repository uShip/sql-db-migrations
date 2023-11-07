SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO




CREATE OR ALTER PROCEDURE [dbo].[sp_Accounts_GetBillingDetails_Ver3__OPT202311]
  @UserID INT,
  @StartDate DATETIME = NULL,
  @EndDate DATETIME = NULL,
  @Identifier INT = 0,
  @TransactionType VARCHAR(15) = NULL,
  @IsPackageMatch BIT = 0
AS
   BEGIN   
         SET NOCOUNT ON ;
    
        DECLARE @CreditLaunchDate AS DATETIME
        DECLARE @StartDateBINBug AS DATETIME
        DECLARE @EndDateBINBug AS DATETIME
        DECLARE @TerrapassInclusive DATETIME    
        
        SET @CreditLaunchDate = '2/11/2009 7:45 PM'
        SET @StartDateBINBug = '4/7/2009 18:30'
        SET @EndDateBINBug = '4/17/2009 13:00'
        SET @TerrapassInclusive = '10/20/2011 14:48'

		SET @StartDate = ISNULL(@StartDate, '1990-01-01');
		SET @EndDate = ISNULL(@EndDate, GETDATE());
        
        CREATE TABLE #InvoiceItemTemp
            (
              InvoiceItemID INT primary key,
              Identifier INT,
              DateCreated DATETIME,
        CurrencyConverterRateGroupID INT,
              AmountToCharge MONEY,
              CurrencyID INT,
              InvoiceID INT,
              NumIdentifier INT,
              TransactionType VARCHAR(15),
              IsPackageMatch BIT NULL
            )
			;

        INSERT  INTO #InvoiceItemTemp
                (
                  InvoiceItemID,
                  Identifier,
                  DateCreated,
          CurrencyConverterRateGroupID,
                  AmountToCharge,
                  CurrencyID,
                  InvoiceID,
                  NumIdentifier,
                  TransactionType,
                  IsPackageMatch
                )
                SELECT DISTINCT
                        ii.InvoiceItemID,
                        ii.Identifier,
                        DATEADD(mi, DATEDIFF(mi, 0, ii.DateCreated), 0),
            ii.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                        ii.AmountToCharge,
                        COALESCE(ii.CurrencyID, 1),
                        ii.InvoiceID,
                        ii.Identifier AS NumIdentifier,
                        'bid' AS TransactionType,
                        1 AS IsPackageMatch
                FROM    Financial.InvoiceItems ii
                        INNER JOIN Financial.Invoices i ON i.InvoiceID = ii.InvoiceID
                        INNER JOIN Marketplace.Bids pm ON pm.PackageMatchID = ii.Identifier
                        INNER JOIN Marketplace.Listings p ON p.PackageID = pm.PackageID
                WHERE   i.UserID = @UserID
                        AND (ii.DateCreated BETWEEN @StartDate AND @EndDate)
                        AND (ii.ItemTypeID IN ( 29, 30 )
                              OR (ii.ItemTypeID NOT IN ( 10, 11, 14, 15, 16, 19, 32 ))
                              OR (ii.ItemTypeID = 15 AND ii.DateCreated > @TerrapassInclusive)
                              OR (ii.ItemTypeID = 16 AND ii.DateCreated > @TerrapassInclusive)
                            )
                        
        DECLARE @Amount TABLE
            (
              Identifier INT,
              AmountToCharge MONEY,
              DateCreated DATETIME
            )
            
        INSERT  INTO @Amount
                (
                  Identifier,
                  AmountToCharge,
                  DateCreated                  
                )
                SELECT  t.Identifier,
                        SUM(t.AmountToCharge),
                        t.DateCreated
                FROM    #InvoiceItemTemp t
                GROUP BY t.Identifier,
                         t.DateCreated
        /** Adding currency conversion stuff here - bbaxter***/                
        SELECT DISTINCT
                *
        FROM    ( SELECT    t.InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            'BO1' + CAST(t.Identifier AS VARCHAR) AS Identifier,
                            ii.PromotionID,
                            t.DateCreated,
              ii.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            CASE WHEN otci.TransactionCodeItemID IS NOT NULL -- If it's a broker pay through then return the 2nd leg bid amount
                 THEN pm.CounterOffer
                 WHEN pay.PaymentID IS NOT NULL
                                      AND pay.PaymentTypeID <> 105
                                 THEN pay.Amount
                                 WHEN pay.PaymentID IS NOT NULL
                                      AND pay.PaymentTypeID = 105
                                 THEN a.AmountToCharge + pay.Amount
                                 WHEN pay.PaymentID IS NULL
                                      AND pm.AutoAccept = 1
                                      AND ii.DateCreated > @CreditLaunchDate
                                      AND ii.DateCreated < @StartDateBINBug
                                      AND ii.DateCreated >= @EndDateBINBug
                                 THEN 0
                                 --Show Amount To You, instead of Booked Price
                                 WHEN ii22.InvoiceItemID IS NOT NULL
                                 THEN ii22.AmountToCharge
                                 ELSE a.AmountToCharge
                            END AS AmountToCharge,
                            CASE WHEN ii22.InvoiceItemID IS NOT NULL THEN 22
                 WHEN otci.TransactionCodeItemID IS NOT NULL THEN 22
                                 ELSE ii.ItemTypeID
                            END AS ItemTypeID,
                            CASE WHEN pm.AutoAccept = 1 THEN laa.Version
                                 ELSE 0
                            END AutoAccept,
                            CASE WHEN bl.BrokeredListingId IS NOT NULL THEN 1
                                 ELSE 0
                            END AS IsBrokered,
                            0 AS PaymentType,
                            p.Title,
                            p.GeneratedID,
                            p.UserID AS ShipperID,
                            'TSP' AS [Role],
                            COALESCE(ii.PayNumber, '') AS PayNumber,
                            COALESCE(ii.Note, '') AS Note,
                            t.CurrencyID,
                            t.InvoiceID,
			                COALESCE (tci.held, otci.held, 0) AS TransactionCodeheld,
                            t.Identifier AS NumIdentifier,
                            'bid' AS TransactionType,
                            1 AS IsPackageMatch,
              0 AS IdentifierType,
              COALESCE (tci.Activated, otci.Activated) AS TransactionCodeActive
                  FROM      #InvoiceItemTemp t
                            INNER JOIN Financial.InvoiceItems ii ON t.InvoiceItemID = ii.InvoiceItemID
                            LEFT JOIN Financial.InvoiceItems ii22 ON ii22.Identifier = ii.Identifier
                                                 AND ii22.InvoiceID = ii.InvoiceID
                                                 AND ii22.ItemTypeID = 22
                            LEFT JOIN Financial.TransactionCodes tc ON tc.InvoiceItemID = ii22.InvoiceItemID
                            LEFT JOIN (SELECT TransactionCodeID,
					          			MAX(CAST(Hidden AS INT)) Hidden,
					          			MAX(CAST(Activated AS INT)) Activated,
					          			dbo.UFNS_IsHeldTransactionCodeItemStatus(TransactionCodeItemStatus) as held
					          		FROM Financial.TransactionCodeItems
					          		GROUP BY TransactionCodeID, TransactionCodeItemStatus) tci ON tci.TransactionCodeID = tc.TransactionCodeID
                            INNER JOIN @Amount a ON t.Identifier = a.Identifier
                                                    AND t.DateCreated = a.DateCreated
                            INNER JOIN Marketplace.Bids pm ON t.Identifier = pm.PackageMatchID
                            INNER JOIN Marketplace.Listings p ON p.PackageID = pm.PackageID
                            LEFT JOIN Marketplace.ListingAutoAccepts laa ON laa.PackageID = p.PackageID
                            LEFT JOIN Financial.Payments pay ON pay.Identifier = t.Identifier
                                                              AND pay.UserID = @UserID
                            LEFT JOIN Marketplace.BrokeredListings bl ON bl.BrokeredListingId = p.PackageID
                            LEFT JOIN Marketplace.Listings op ON op.PackageID = bl.OriginalListingId  -- See if this is Broker Pay Through, if it is then get the original match to get the code
                            LEFT JOIN Marketplace.Bids ob ON ob.PackageID = op.PackageID
                            LEFT JOIN Financial.InvoiceItems oii22 ON oii22.Identifier = ob.PackageMatchID
                                                  AND oii22.ItemTypeID = 22
                            LEFT JOIN Financial.TransactionCodes otc ON otc.InvoiceItemID = oii22.InvoiceItemID
                            LEFT JOIN (SELECT TransactionCodeID,
			  			                  TransactionCodeItemID,
			  			                  UserId,
			  			                  MAX(CAST(Activated AS INT)) Activated,
			  		                      dbo.UFNS_IsHeldTransactionCodeItemStatus(TransactionCodeItemStatus) as held
			             FROM   Financial.TransactionCodeItems
			             GROUP BY TransactionCodeID, TransactionCodeItemStatus,TransactionCodeItemID, UserId) otci ON otci.TransactionCodeID = otc.TransactionCodeID	AND otci.UserID = @UserID
                  WHERE     ii.ItemTypeID = 1
              AND (ii22.InvoiceItemID IS NULL OR tci.Hidden = 0) -- TSP Shipment Match or Total Payment
                  UNION
                  SELECT    t.InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            'BO1' + CAST(t.Identifier AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            t.DateCreated,
              ii.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            CASE WHEN pay.PaymentID IS NOT NULL
                                      AND pay.PaymentTypeID <> 105
                                 THEN -pay.Amount
                                 WHEN pay.PaymentID IS NOT NULL
                                      AND pay.PaymentTypeID = 105
                                 THEN a.AmountToCharge - pay.Amount
                                 WHEN pay.PaymentID IS NULL
                                      AND pm.AutoAccept = 1
                                      AND laa.Version = 1
                                      AND pm.DateCreated > @CreditLaunchDate
                                 THEN 0
                                 ELSE a.AmountToCharge
                            END AS AmountToCharge,
                            CASE WHEN ii24.InvoiceItemID IS NOT NULL THEN 24
                                 ELSE ii.ItemTypeID
                            END AS ItemTypeID,
                            CASE WHEN pm.AutoAccept = 1 THEN laa.Version
                                 ELSE 0
                            END AutoAccept,
                            CASE WHEN bl.BrokeredListingId IS NOT NULL THEN 1
                                 ELSE 0
                            END AS IsBrokered,
                            0 AS PaymentType,
                            p.Title,
                            p.GeneratedID,
                            p.UserID AS ShipperID,
                            'TSP' AS [Role],
                            COALESCE(ii.PayNumber, '') AS PayNumber,
                            COALESCE(ii.Note, '') AS Note,
                            t.CurrencyID,
                            t.InvoiceID,
                            0 as TransactionCodeheld,
                            t.Identifier AS NumIdentifier,
                            'bid' AS TransactionType,
                            1 AS IsPackageMatch,
              0 AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      #InvoiceItemTemp t
                            INNER JOIN Financial.InvoiceItems ii ON t.InvoiceItemID = ii.InvoiceItemID
              LEFT JOIN Financial.InvoiceItems ii24 ON ii24.Identifier = ii.Identifier
                                   AND ii24.InvoiceID = ii.InvoiceID
                                   AND ii24.ItemTypeID = 24
                            INNER JOIN @Amount a ON t.Identifier = a.Identifier
                                                    AND t.DateCreated = a.DateCreated
                            INNER JOIN Marketplace.Bids pm ON t.Identifier = pm.PackageMatchID
                            INNER JOIN Marketplace.Listings p ON p.PackageID = pm.PackageID
                            LEFT JOIN Marketplace.ListingAutoAccepts laa ON laa.PackageID = p.PackageID
                            LEFT JOIN Financial.Payments pay ON pay.Identifier = t.Identifier
                                                              AND pay.UserID = @UserID
                            LEFT JOIN Marketplace.BrokeredListings bl ON bl.BrokeredListingId = p.PackageID
                  WHERE     ii.ItemTypeID = 2 -- TSP Match Retraction                                        
                  UNION
                  SELECT    t.InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            'BO1' + CAST(t.Identifier AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            t.DateCreated,
                            ii.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            a.AmountToCharge,
                            ii.ItemTypeID,
                            pm.AutoAccept,
                            CASE WHEN bl.BrokeredListingId IS NOT NULL THEN 1
                                 ELSE 0
                            END AS IsBrokered,
                            0 AS PaymentType,
                            p.Title,
                            p.GeneratedID,
                            p.UserID AS ShipperID,
                            'Shipper' AS [Role],
                            COALESCE(ii.PayNumber, '') AS PayNumber,
                            COALESCE(ii.Note, '') AS Note,
                            t.CurrencyID,
                            t.InvoiceID,
                            tci.held as TransactionCodeheld,
                            t.Identifier AS NumIdentifier,
                            'bid' AS TransactionType,
                            1 AS IsPackageMatch,
                            0 AS IdentifierType,
                            NULL as TransactionCodeActive
                  FROM      #InvoiceItemTemp t
                            INNER JOIN Financial.InvoiceItems ii ON t.InvoiceItemID = ii.InvoiceItemID
                            INNER JOIN @Amount a ON t.Identifier = a.Identifier
                                                    AND t.DateCreated = a.DateCreated
                            INNER JOIN Marketplace.Bids pm ON t.Identifier = pm.PackageMatchID
                            INNER JOIN Marketplace.Listings p ON p.PackageID = pm.PackageID
                            LEFT JOIN Marketplace.BrokeredListings bl ON bl.BrokeredListingId = p.PackageID
							LEFT JOIN (SELECT BidId,
					          			MAX(CAST(Hidden AS INT)) Hidden,
					          			MAX(CAST(Activated AS INT)) Activated,
					          			dbo.UFNS_IsHeldTransactionCodeItemStatus(TransactionCodeItemStatus) as held
					          		FROM Financial.TransactionCodeItems
					          		GROUP BY BidId, TransactionCodeItemStatus) tci ON tci.BidId = pm.PackageMatchID
                  WHERE     ii.ItemTypeID IN ( 9, 20 ) -- Shipper Shipment Match
                  UNION
                  SELECT    t.InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            '' AS Identifier,
                            0 AS PromotionID,
                            t.DateCreated,
              ii.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            ii.AmountToCharge,
                            ii.ItemTypeID,
                            0 AS AutoAccept,
                            0 AS IsBrokered,
                            0 AS PaymentType,
                            '' AS Title,
                            0 AS GeneratedID,
                            0 AS ShipperID,
                            '' AS [Role],
                            COALESCE(ii.PayNumber, '') AS PayNumber,
                            COALESCE(ii.Note, '') AS Note,
                            t.CurrencyID,
                            t.InvoiceID,
              0 as TransactionCodeheld,
                            0 AS NumIdentifier,
                            'fee' AS TransactionType,
                            NULL AS IsPackageMatch,
              0 AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      #InvoiceItemTemp t
                            INNER JOIN Financial.InvoiceItems ii ON t.InvoiceItemID = ii.InvoiceItemID
                            INNER JOIN @Amount a ON t.Identifier = a.Identifier
                                                    AND t.DateCreated = a.DateCreated
                  WHERE     ii.ItemTypeID IN ( 6, 7 ) -- Interest, Late Fee
                  UNION
                  SELECT    ii.InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            '' AS Identifier,
                            0 AS PromotionID,
                            ii.DateCreated,
              ii.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            -ii.AmountToCharge,
                            ii.ItemTypeID,
                            0 AS AutoAccept,
                            0 AS IsBrokered,
                            0 AS PaymentType,
                            '' AS Title,
                            0 AS GeneratedID,
                            0 AS ShipperID,
                            '' AS [Role],
                            '' AS PayNumber,
                            COALESCE(ii.Note, '') AS Note,
                            COALESCE(ii.CurrencyID, 1) AS CurrencyID,
                            ii.InvoiceID,
              0 as TransactionCodeheld,
                            0 AS NumIdentifier,
                            'bid' AS TransactionType,
                            1 AS IsPackageMatch,
              0 AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      Financial.InvoiceItems ii
                            INNER JOIN Financial.Invoices i ON i.InvoiceID = ii.InvoiceID
                            INNER JOIN Account.CreditReasons cr ON cr.CreditReasonID = ii.Identifier
                  WHERE     i.UserID = @UserID
                            AND (ii.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND ii.ItemTypeID = 14 -- AdHoc credit from Admin
                  UNION
                  SELECT    ii.InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            'BO1' + CAST(ii.Identifier AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            ii.DateCreated,
              ii.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            -ii.AmountToCharge,
                            ii.ItemTypeID,
                            pm.AutoAccept,
                            CASE WHEN bl.BrokeredListingId IS NOT NULL THEN 1
                                 ELSE 0
                            END AS IsBrokered,
                            0 AS PaymentType,
                            p.Title,
                            p.GeneratedID,
                            p.UserID AS ShipperID,
                            '' AS [Role],
                            '' AS PayNumber,
                            COALESCE(ii.Note, '') AS Note,
                            COALESCE(ii.CurrencyID, 1) AS CurrencyID,
                            ii.InvoiceID,
              0 as TransactionCodeheld,
                            ii.Identifier AS NumIdentifier,
                            'bid' AS TransactionType,
                            1 AS IsPackageMatch,
              0 AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      Financial.InvoiceItems ii
                            INNER JOIN Financial.Invoices i ON i.InvoiceID = ii.InvoiceID
                            INNER JOIN Marketplace.Bids pm ON ii.Identifier = pm.PackageMatchID
                            INNER JOIN Marketplace.Listings p ON p.PackageID = pm.PackageID
                            LEFT JOIN Account.CreditReasons cr ON cr.CreditReasonID = ii.Identifier
                            LEFT JOIN Marketplace.BrokeredListings bl ON bl.BrokeredListingId = p.PackageID
                  WHERE     i.UserID = @UserID
                            AND (ii.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND ii.ItemTypeID = 14
                            AND cr.CreditReasonID IS NULL -- AdHoc credit from matches    
                  UNION
                  SELECT    0 AS InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            '' AS Identifier,
                            0 AS PromotionID,
                            DATEADD(mi, DATEDIFF(mi, 0, ubl.DateCreated), 0) AS DateCreated,
              ubl.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            ubl.Amount AmountToCharge,
                            14 AS ItemTypeID,
                            0 AS AutoAccept,
                            0 AS IsBrokered,
                            0 AS PaymentType,
                            '' AS Title,
                            0 AS GeneratedID,
                            0 AS ShipperID,
                            '' AS [Role],
                            '' AS PayNumber,
                            '' AS Note,
                            COALESCE(ubl.CurrencyID, 1) AS CurrencyID,
                            0 AS InvoiceID,
              0 as TransactionCodeheld,
                            0 AS NumIdentifier,
                            'bid' AS TransactionType,
                            1 AS IsPackageMatch,
              ubl.IdentifierType AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      Financial.UserBalances ubl
                  WHERE     ubl.UserID = @UserID
                            AND (ubl.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND ubl.Amount < 0
                            AND ubl.IdentifierType NOT IN ( 3, 6, 13 )
                  UNION
                  SELECT    0 AS InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            '' AS Identifier,
                            0 AS PromotionID,
                            ubl.DateCreated AS DateCreated,
              ubl.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            ubl.Amount AmountToCharge,
                            4 AS ItemTypeID, -- UnpaidBalance
                            0 AS AutoAccept,
                            0 AS IsBrokered,
                            0 AS PaymentType,
                            '' AS Title,
                            0 AS GeneratedID,
                            0 AS ShipperID,
                            '' AS [Role],
                            '' AS PayNumber,
                            '' AS Note,
                            COALESCE(ubl.CurrencyID, 1) AS CurrencyID,
                            0 AS InvoiceID,
              0 as TransactionCodeheld,
                            ubl.Identifier AS NumIdentifier,
                            'bid' AS TransactionType,
                            1 AS IsPackageMatch,
              ubl.IdentifierType AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      Financial.UserBalances ubl
                  WHERE     ubl.UserID = @UserID
                            AND (ubl.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND ubl.Amount > 0
                            AND ubl.IdentifierType in (10,11) --A debit that is added from admin or ACH Failure
                  UNION
                  SELECT    0 AS InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            'BO1' + CAST(ubl.Identifier AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            ubl.DateCreated AS DateCreated,
              ubl.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            ubl.Amount AmountToCharge,
                            4 AS ItemTypeID, -- UnpaidBalance
                            0 AS AutoAccept,
                            0 AS IsBrokered,
                            0 AS PaymentType,
                            l.Title AS Title,
                            l.GeneratedID,
                            l.UserID AS ShipperID,
                            CASE WHEN ubl.UserID = b.UserID THEN 'TSP'
                 ELSE 'Shipper' END AS [Role],
                            '' AS PayNumber,
                            '' AS Note,
                            COALESCE(ubl.CurrencyID, 1) AS CurrencyID,
                            0 AS InvoiceID,
              0 as TransactionCodeheld,
                            ubl.Identifier AS NumIdentifier,
                            'bid' AS TransactionType,
                            1 AS IsPackageMatch,
              ubl.IdentifierType AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      Financial.UserBalances ubl
              INNER JOIN Marketplace.Bids b ON b.PackageMatchID = ubl.Identifier
              INNER JOIN Marketplace.Listings l ON l.PackageID = b.PackageID
                  WHERE     ubl.UserID = @UserID
                            AND (ubl.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND ubl.Amount > 0
                            AND ubl.IdentifierType IN (2, 4, 8) --A debit from transactions
                  UNION
                  SELECT    ii.InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            'BO1' + CAST(ii.Identifier AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            ii.DateCreated,
              ii.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            ii.AmountToCharge,
                            ii.ItemTypeID,
                            0 AS AutoAccept,
                            CASE WHEN bl.BrokeredListingId IS NOT NULL THEN 1
                                 ELSE 0
                            END AS IsBrokered,
                            0 AS PaymentType,
                            p.Title,
                            p.GeneratedID,
                            p.UserID AS ShipperID,
                            'TSP' AS [Role],
                            '' AS PayNumber,
                            COALESCE(ii.Note, '') AS Note,
                            COALESCE(ii.CurrencyID, 1) AS CurrencyID,
                            ii.InvoiceID,
              0 as TransactionCodeheld,
                            ii.Identifier AS NumIdentifier,
                            'bid' AS TransactionType,
                            1 AS IsPackageMatch,
              0 AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      Financial.InvoiceItems ii
                            INNER JOIN Financial.Invoices i ON i.InvoiceID = ii.InvoiceID
                            INNER JOIN Marketplace.Bids pm ON ii.Identifier = pm.PackageMatchID
                            INNER JOIN Marketplace.Listings p ON p.PackageID = pm.PackageID
                            LEFT JOIN Marketplace.BrokeredListings bl ON bl.BrokeredListingId = p.PackageID
                  WHERE     i.UserID = @UserID
                            AND (ii.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND ii.ItemTypeID IN ( 15, 16 ) -- TSP Terrapass and Terrapass Retraction
                            AND ii.DateCreated <= @TerrapassInclusive
                  UNION
                  SELECT    MAX(ii.InvoiceItemID) AS InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            'BO1' + CAST(t.Identifier AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            t.DateCreated,
              ii.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            a.AmountToCharge,
                            ii.ItemTypeID,
                            0 AS AutoAccept,
                            CASE WHEN bl.BrokeredListingId IS NOT NULL THEN 1
                                 ELSE 0
                            END AS IsBrokered,
                            0 AS PaymentType,
                            p.Title,
                            p.GeneratedID,
                            p.UserID AS ShipperID,
                            'Shipper' AS [Role],
                            COALESCE(ii.PayNumber, '') AS PayNumber,
                            COALESCE(ii.Note, '') AS Note,
                            t.CurrencyID,
                            t.InvoiceID,
              0 as TransactionCodeheld,
                            t.Identifier AS NumIdentifier,
                            'listing' AS TransactionType,
                            0 AS IsPackageMatch,
              0 AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      #InvoiceItemTemp t
                            INNER JOIN Financial.InvoiceItems ii ON t.InvoiceItemID = ii.InvoiceItemID
                            INNER JOIN @Amount a ON t.Identifier = a.Identifier
                                                    AND t.DateCreated = a.DateCreated
                            INNER JOIN Marketplace.Listings p ON p.PackageID = t.Identifier
                            LEFT JOIN Marketplace.BrokeredListings bl ON bl.BrokeredListingId = p.PackageID
                  WHERE     ii.ItemTypeID = 17 -- Listing Upgrade    
                  GROUP BY  t.Identifier, t.DateCreated, a.AmountToCharge, ii.ItemTypeID, ii.CurrencyConverterRateGroupID, bl.BrokeredListingId,
                            p.Title, p.GeneratedID, p.UserID, PayNumber, Note, t.CurrencyID, t.InvoiceID
                  UNION
                  -- Pro Subscription
                  SELECT    ii.InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            'BO1' + CAST(ii.InvoiceItemID AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            ii.DateCreated,
              ii.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            ii.AmountToCharge,
                            ii.ItemTypeID,
                            0 AS AutoAccept,
                            0 AS IsBrokered,
                            0 AS PaymentType,
                            '' AS Title,
                            0 AS GeneratedID,
                            0 AS ShipperID,
                            '' AS [Role],
                            '' AS PayNumber,
                            COALESCE(ii.Note, '') AS Note,
                            COALESCE(ii.CurrencyID, 1) AS CurrencyID,
                            ii.InvoiceID,
              0 as TransactionCodeheld,
                            ii.invoiceItemID,
                            'subscription' AS TransactionType,
                            NULL AS IsPackageMatch,
              0 AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      Financial.InvoiceItems ii
                            INNER JOIN Financial.Invoices i ON i.InvoiceID = ii.InvoiceID
                  WHERE     i.UserID = @UserID
                            AND (ii.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND ii.ItemTypeID = 32 -- Pro Subscription Fee
                  UNION
                  SELECT    0 AS InvoiceItemID,
                            p.PaymentID,
                            0 AS PayoutID,
                            'IP' + CAST(p.PaymentID AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            DATEADD(mi, DATEDIFF(mi, 0, p.DateCreated), 0) AS DateCreated,
              p.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            p.Amount AmountToCharge,
                            0 AS ItemTypeID, -- Payment                              
                            0 AS AutoAccept,
                            0 AS IsBrokered,
                            p.PaymentTypeID AS PaymentType,
                            '' AS Title,
                            0 AS GeneratedID,
                            0 AS ShipperID,
                            '' AS [Role],
                            '' AS PayNumber,
                            p.Note,
                            COALESCE(p.CurrencyID, 1) AS CurrencyID,
                            0 AS InvoiceID,
              0 as TransactionCodeheld,
                            p.Identifier,
                            'bid' AS TransactionType,
                            1 AS IsPackageMatch,
              0 AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      Financial.Payments p
                  WHERE     p.UserID = @UserID
                            AND (p.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND p.PaymentTypeID <> 105
                  UNION
                  SELECT    0 AS InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            'C01' + CAST(uba.ToIdentifier AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            DATEADD(mi, DATEDIFF(mi, 0, MIN(uba.DateCreated)), 0) AS DateCreated,
              ubl.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            -SUM(uba.Amount * uba.ConversionRate) AS AmountToCharge,
                            -4 AS ItemTypeID, -- Shipper credit applied                              
                            0 AS AutoAccept,
                            CASE WHEN MAX(bl.BrokeredListingId) IS NOT NULL THEN 1
                                 ELSE 0
                            END AS IsBrokered,
                            0 AS PaymentType,
                            p.Title,
                            p.GeneratedID,
                            p.UserID AS ShipperID,
                            'Shipper' AS [Role],
                            '' AS PayNumber,
                            '' AS Note,
                            COALESCE(MAX(pm.CurrencyID), 1) AS CurrencyID,
                            0 AS InvoiceID,
              0 as TransactionCodeheld,
                            uba.ToIdentifier,
                            'bid' AS TransactionType,
                            1 AS IsPackageMatch,
              0 AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      Financial.UserBalanceAllocations uba
                            INNER JOIN Marketplace.Bids pm ON pm.PackageMatchID = uba.ToIdentifier
                            INNER JOIN Marketplace.Listings p ON p.PackageID = pm.PackageID
              INNER JOIN Financial.UserBalances ubl on ubl.LogID=uba.SourceLogID
                            LEFT JOIN Marketplace.BrokeredListings bl ON bl.BrokeredListingId = p.PackageID
                  WHERE     uba.UserID = @UserID
                            AND (uba.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND uba.IdentifierType = 3 -- ShipperPackageMatchID
                            AND uba.Amount < 0
                  GROUP BY  uba.ToIdentifier,
              ubl.CurrencyConverterRateGroupID,
                            p.Title,
                            p.GeneratedID,
                            p.UserID
                  UNION
                  SELECT    0 AS InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            'BO1' + CAST(uba.ToIdentifier AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            MIN(uba.DateCreated) AS DateCreated,
              ubl.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            -SUM(uba.Amount * uba.ConversionRate) AS AmountToCharge,
                            -8 AS ItemTypeID, -- LTL Complimentary Credit
                            0 AS AutoAccept,
                            0 AS IsBrokered,
                            0 AS PaymentType,
                            p.Title,
                            p.GeneratedID,
                            p.UserID AS ShipperID,
                            'Shipper' AS [Role],
                            '' AS PayNumber,
                            '' AS Note,
                            COALESCE(MAX(pm.CurrencyID), 1) AS CurrencyID,
                            0 AS InvoiceID,
              0 as TransactionCodeheld,
                            uba.ToIdentifier,
                            'bid' AS TransactionType,
                            1 AS IsPackageMatch,
              0 AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      Financial.UserBalanceAllocations uba
                            INNER JOIN Marketplace.Bids pm ON pm.PackageMatchID = uba.ToIdentifier
                            INNER JOIN Marketplace.Listings p ON p.PackageID = pm.PackageID
              INNER JOIN Financial.UserBalances ubl on ubl.LogID=uba.SourceLogID
                  WHERE     uba.UserID = @UserID
                            AND (uba.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND uba.IdentifierType = 26 -- LTLComplimentaryCredit
                  GROUP BY  uba.ToIdentifier,
              ubl.CurrencyConverterRateGroupID,
                            p.Title,
                            p.GeneratedID,
                            p.UserID
                  UNION
                  SELECT    0 AS InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            'BO1' + CAST(ref.Identifier AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            DATEADD(mi, DATEDIFF(mi, 0, ref.DateCreated), 0) AS DateCreated,
              p.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            -ref.RefundAmount AmountToCharge,
                            -1 AS ItemTypeID, -- Match cancellation refund                              
                            0 AS AutoAccept,
                            CASE WHEN bl.BrokeredListingId IS NOT NULL THEN 1
                                 ELSE 0
                            END AS IsBrokered,
                            0 AS PaymentType,
                            p.Title,
                            p.GeneratedID,
                            p.UserID AS ShipperID,
                            'Shipper' AS [Role],
                            '' AS PayNumber,
                            '' AS Note,
                            COALESCE(pay.CurrencyID, 1) AS CurrencyID,
                            0 As InvoiceID,
              0 as TransactionCodeheld,
                            ref.Identifier,
                            'bid' AS TransactionType,
                            1 AS IsPackageMatch,
              0 AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      Financial.Refunds ref
                            INNER JOIN Financial.Payments pay ON ref.PaymentID = pay.PaymentID
                            INNER JOIN Marketplace.Bids pm ON ref.identifier = pm.PackageMatchID
                            INNER JOIN Marketplace.Listings p ON pm.PackageID = p.PackageID
                            LEFT JOIN Marketplace.BrokeredListings bl ON bl.BrokeredListingId = p.PackageID
                  WHERE     pay.UserID = @UserID
                            AND p.UserID = pay.UserID
                            AND pay.typeID = 1
                            AND (ref.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND ref.Status = 1
                  UNION
                  SELECT    0 AS InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            'CO1' + CAST(ubl.Identifier AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            DATEADD(mi, DATEDIFF(mi, 0, ubl.DateCreated), 0) AS DateCreated,
              ubl.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            ubl.Amount - COALESCE(uba.Amount, 0) AmountToCharge,
                            -5 AS ItemTypeID, -- Match cancellation credit                              
                            0 AS AutoAccept,
                            CASE WHEN bl.BrokeredListingId IS NOT NULL THEN 1
                                 ELSE 0
                            END AS IsBrokered,
                            0 AS PaymentType,
                            p.Title,
                            p.GeneratedID,
                            p.UserID AS ShipperID,
                            'Shipper' AS [Role],
                            '' AS PayNumber,
                            '' AS Note,
                            COALESCE(ubl.CurrencyID, 1) AS CurrencyID,
                            0 AS InvoiceID,
              0 as TransactionCodeheld,
                            ubl.Identifier,
                            'bid' AS TransactionType,
                            1 AS IsPackageMatch,
              ubl.IdentifierType AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      Financial.UserBalances ubl
                            INNER JOIN Marketplace.Bids pm ON ubl.Identifier = pm.PackageMatchID
                            INNER JOIN Marketplace.Listings p ON pm.PackageID = p.PackageID
                            LEFT JOIN Marketplace.BrokeredListings bl ON bl.BrokeredListingId = p.PackageID
              LEFT JOIN ( SELECT  SourceLogID, 
                        SUM(Amount) Amount
                    FROM  Financial.UserBalanceAllocations
                    WHERE Deallocated = 0
                        AND IdentifierType = 23
                    GROUP BY SourceLogID) uba ON uba.SourceLogID = ubl.LogID
                  WHERE     ubl.UserID = @UserID
                            AND ubl.IdentifierType = 6 -- Cancellation credit
                            AND p.UserID = ubl.UserID
              AND COALESCE(uba.Amount, 0) <> ubl.Amount
                            AND (ubl.DateCreated BETWEEN @StartDate AND @EndDate)
                  UNION
          -- bbaxter - split into two items
                  SELECT    0 AS InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            'BO1' + CAST(ref.Identifier AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            DATEADD(mi, DATEDIFF(mi, 0, ref.DateCreated), 0) AS DateCreated,
              p.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            -pay.Amount AmountToCharge,
                            77 AS ItemTypeID, -- Listing upgrade refund                              
                            0 AS AutoAccept,
                            CASE WHEN bl.BrokeredListingId IS NOT NULL THEN 1
                                 ELSE 0
                            END AS IsBrokered,
                            0 AS PaymentType,
                            p.Title,
                            p.GeneratedID,
                            p.UserID AS ShipperID,
                            'Shipper' AS [Role],
                            '' AS PayNumber,
                            '' AS Note,
                            COALESCE(pay.CurrencyID, 1) AS CurrencyID,
                            0 AS InvoiceID,
              0 as TransactionCodeheld,
                            ref.Identifier,
                            'listing' AS TransactionType,
                            0 AS IsPackageMatch,
              0 AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      Financial.Refunds ref
                            INNER JOIN Financial.Payments pay ON ref.PaymentID = pay.PaymentID
                            INNER JOIN Marketplace.Listings p ON ref.identifier = p.PackageID
                            LEFT JOIN Marketplace.BrokeredListings bl ON bl.BrokeredListingId = p.PackageID
                  WHERE     pay.UserID = @UserID
                            AND p.UserID = pay.UserID
                            AND pay.typeID = 2
                            AND (ref.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND ref.Status = 1
                  UNION
                  --WITHDRAWAL FROM ACTIVATED USHIP PAYMENT CODE
          SELECT    0 AS InvoiceItemID,
                            0 AS PaymentID,
                            w.PayoutID,
                            'W01' + CAST(w.PayoutID AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            MIN(DATEADD(mi, DATEDIFF(mi, 0, w.DateCreated), 0)) AS DateCreated,
              w.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            -( SUM(tci.Amount) ) AS AmountToCharge,
                            -7 AS ItemTypeID, -- WithdrawalFromActivatedCode                              
                            0 AS AutoAccept,
                            0 AS IsBrokered,
                            MIN(w.PaymentTypeID) AS PaymentType,
                            '' AS Title,
                            0 AS GeneratedID,
                            0 AS ShipperID,
                            'TSP' AS [Role],
                            '' AS PayNumber,
                            MIN(w.Note),
                            w.CurrencyID,
                            0 AS InvoiceID,
              0 as TransactionCodeheld,
                            w.PayoutID,
                            'payout' AS TransactionType,
                            NULL AS IsPackageMatch,
              0 AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      Financial.Payouts w
              INNER JOIN Financial.TransactionCodeItems tci ON tci.PayoutID = w.PayoutID
              INNER JOIN Financial.TransactionCodes tc on tci.TransactionCodeID = tc.TransactionCodeID
                  WHERE     w.UserID = @UserID
                            AND (w.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND w.PayoutTypeID = 13 --uShip Payment
                            AND tc.CodeTypeID IN ( 1, 3 ) --uShip Payment, Vehicle Ordered & Not Used
                  GROUP BY  w.PayoutID, w.CurrencyConverterRateGroupID, w.CurrencyID
                  HAVING  SUM(tci.Amount) > 0
                  UNION
                  --EARLY WITHDRAWAL FEE
          SELECT    0 AS InvoiceItemID,
                            0 AS PaymentID,
                            w.PayoutID,
                            'W01' + CAST(w.PayoutID AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            MIN(DATEADD(mi, DATEDIFF(mi, 0, w.DateCreated), 0)) AS DateCreated,
              w.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            ( SUM(tci.Fee) ) AS AmountToCharge,
                            31 AS ItemTypeID, -- EarlyWithdrawalFee                              
                            0 AS AutoAccept,
                            0 AS IsBrokered,
                            MIN(w.PaymentTypeID) AS PaymentType,
                            '' AS Title,
                            0 AS GeneratedID,
                            0 AS ShipperID,
                            'TSP' AS [Role],
                            '' AS PayNumber,
                            MIN(w.Note),
                            w.CurrencyID,
                            0 AS InvoiceID,
              0 as TransactionCodeheld,
                            w.PayoutID,
                            'payout' AS TransactionType,
                            NULL AS IsPackageMatch,
              0 AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      Financial.Payouts w
              INNER JOIN Financial.TransactionCodeItems tci ON tci.PayoutID = w.PayoutID
              INNER JOIN Financial.TransactionCodes tc on tci.TransactionCodeID = tc.TransactionCodeID
                  WHERE     w.UserID = @UserID
                            AND (w.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND w.PayoutTypeID = 13 --uShip Payment
                            AND tc.CodeTypeID = 2 --Early Withdrawal
                  GROUP BY  w.PayoutID, w.CurrencyConverterRateGroupID, w.CurrencyID
                  UNION
                  -- Credits for ListingFee
                  SELECT    0 AS InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            'C01' + CAST(uba.ToIdentifier AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            DATEADD(mi, DATEDIFF(mi, 0, MIN(uba.DateCreated)), 0) AS DateCreated,
              ubl.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            -SUM(uba.Amount * uba.ConversionRate) AS AmountToCharge,
                            -4 AS ItemTypeID, -- Shipper credit applied                              
                            0 AS AutoAccept,
                            CASE WHEN MAX(bl.BrokeredListingId) IS NOT NULL THEN 1
                                 ELSE 0
                            END AS IsBrokered,
                            0 AS PaymentType,
                            p.Title,
                            p.GeneratedID,
                            p.UserID AS ShipperID,
                            'Shipper' AS [Role],
                            '' AS PayNumber,
                            '' AS Note,
                            COALESCE(MAX(p.CurrencyID), 1) AS CurrencyID,
                            0 AS InvoiceID,
              0 as TransactionCodeheld,
                            0.ToIdentifier,
                            'credit' AS TransactionType,
                            NULL AS IsPackageMatch,
             0 AS IdentifierType,
             NULL as TransactionCodeActive
                  FROM      Financial.UserBalanceAllocations uba
                            INNER JOIN Marketplace.Listings p ON p.PackageID = uba.ToIdentifier
                            LEFT JOIN Marketplace.BrokeredListings bl ON bl.BrokeredListingId = p.PackageID
              INNER JOIN Financial.UserBalances ubl on ubl.LogID=uba.SourceLogID
                  WHERE     uba.UserID = @UserID
                            AND (uba.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND uba.IdentifierType = 4 -- ShipperPackageID
                            AND uba.Amount < 0
                  GROUP BY  uba.ToIdentifier,
              ubl.CurrencyConverterRateGroupID,
                            p.Title,
                            p.GeneratedID,
                            p.UserID
               
         UNION
        --Payment Code Activation Line
                SELECT             0 AS InvoiceItemID,
                                        0 AS PaymentID,
                                        0 As PayoutID,
                                        'BO1' + CAST(tci.BidId AS VARCHAR) AS Identifier,
                                        0 AS PromotionID,
                                        tci.DateActivated AS DateCreated,
                    tci.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                                        tci.Amount AS AmountToCharge,
                                        -9 AS ItemTypeID,
                                        0 AS AutoAccept,
                                        0 AS IsBrokered,
                                        0 AS PaymentTypeID, 
                                        p.Title AS Title,
                                        p.GeneratedID AS GeneratedID,
                                        p.UserID AS ShipperID,
                                        'TSP' AS Role,
                                        '' AS PayNumber,
                                        '' AS Note,
                                        tci.CurrencyID AS CurrencyID,
                                        0 AS InvoiceID,
                    0 as TransactionCodeheld,
                                        tci.BidId AS NumIdentifier,
                                        'code activation' AS TransactionType,
                                        1 AS IsPackageMatch,
                                        0.ToIdentifier,
                                        1 AS TransactionCodeActive
                FROM               (
                                        SELECT        DateActivated,
                                                            SUM(Amount) Amount,
                                                            BidId,
                                                            UserId,
                              CurrencyID,
                              CurrencyConverterRateGroupID
                                        FROM          Financial.TransactionCodeItems
                                        GROUP BY      BidId,
                                                            UserId,
                                                            DateActivated,
                              CurrencyID,
                              CurrencyConverterRateGroupID
                                        ) tci
                                        INNER JOIN marketplace.Bids b ON tci.BidId = b.PackageMatchID 
                                                                                                AND b.Accepted = 1 --This might be trouble. Code item for first and second leg are weird
                                        INNER JOIN Marketplace.Listings p ON p.PackageID = b.PackageID
                WHERE                    tci.UserID = @UserID
                                        AND tci.DateActivated IS NOT NULL
                                        AND tci.DateActivated >= @StartDate
                                        AND tci.DateActivated < @EndDate
         UNION  
          -- START bbaxter AHOY-187,188,189: Past Due Debit (BalanceIdentifierType 16,17,18)
          SELECT    0 AS InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            'BO1' + CAST(ubl.Identifier AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            DATEADD(mi, DATEDIFF(mi, 0, ubl.DateCreated), 0) AS DateCreated,
              ubl.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            -ubl.Amount AmountToCharge,
                            -12 AS ItemTypeID, --hack, -12 is past due debit
                            0 AS AutoAccept,
                            0 AS IsBrokered,
                            0 AS PaymentType,
                            '' AS Title,
                            0 AS GeneratedID,
                            0 AS ShipperID,
                            '' AS [Role],
                            '' AS PayNumber,
                            '' AS Note,
                            COALESCE(ubl.CurrencyID, 1) AS CurrencyID,
                            0 AS InvoiceID,
              0 as TransactionCodeheld,
                            0 AS NumIdentifier,
                            '' AS TransactionType,
                            0 AS IsPackageMatch,
              ubl.IdentifierType,
              NULL as TransactionCodeActive
                  FROM      Financial.UserBalances ubl
                  WHERE     ubl.UserID = @UserID
                            AND (ubl.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND ubl.IdentifierType IN (15,16,17,18,19,20)
                  UNION
         -- END bbaxter AHOY-187,188,189: Past Due Debit (BalanceIdentifierType 16,17,18)
         -- START bbaxter AHOY-186: UpfrontWithdrawal (BalanceIdentifierType 7)
          SELECT    0 AS InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            'BO1' + CAST(ubl.Identifier AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            DATEADD(mi, DATEDIFF(mi, 0, ubl.DateCreated), 0) AS DateCreated,
              ubl.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            -ubl.Amount AmountToCharge,
                            -11 AS ItemTypeID, --hack, making -11 a Fast Cash Withdrawal
                            0 AS AutoAccept,
                            0 AS IsBrokered,
                            0 AS PaymentType,
                            '' AS Title,
                            0 AS GeneratedID,
                            0 AS ShipperID,
                            'TSP' AS [Role],
                            '' AS PayNumber,
                            '' AS Note,
                            COALESCE(ubl.CurrencyID, 1) AS CurrencyID,
                            0 AS InvoiceID,
              0 as TransactionCodeheld,
                            0 AS NumIdentifier,
                            '' AS TransactionType,
                            0 AS IsPackageMatch,
              ubl.IdentifierType,
              NULL as TransactionCodeActive
                  FROM      Financial.UserBalances ubl
                  WHERE     ubl.UserID = @UserID
                            AND (ubl.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND ubl.IdentifierType=7
                  UNION
         -- END bbaxter AHOY-186: UpfrontWithdrawal (BalanceIdentifierType 7)
         -- START bbaxter AHOY-183: Debit(s) paid by uPay code activation
         SELECT   0 AS InvoiceItemID, -- baxter - adding line item 21
                        0 AS PaymentID,
                        0 AS PayoutID,
                        'C01' + CAST(uba.ToIdentifier AS VARCHAR) AS Identifier,
                        0 AS PromotionID,
                        MIN(uba.DateCreated) AS DateCreated,
            ubl.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                        SUM(uba.Amount * uba.ConversionRate) AS AmountToCharge,
                        -10 AS ItemTypeID, -- TransactionCodeItemID hack
                        0 AS AutoAccept,
                        0 AS IsBrokered,
                        0 AS PaymentType,
                        '' AS Title,
                        p.GeneratedID,
                        p.UserID AS ShipperID,
                        '' AS [Role],
                        '' AS PayNumber,
                        '' AS Note,
                        COALESCE(MAX(pm.CurrencyID), 1) AS CurrencyID,
                        0 AS InvoiceID,
            0 as TransactionCodeheld,
                        uba.ToIdentifier,
                        '' AS TransactionType,
                        1 AS IsPackageMatch,
            0 AS IdentifierType,
            NULL as TransactionCodeActive
                FROM      Financial.UserBalanceAllocations uba
                        INNER JOIN Marketplace.Bids pm ON pm.PackageMatchID = uba.ToIdentifier
                        INNER JOIN Marketplace.Listings p ON p.PackageID = pm.PackageID
            INNER JOIN Financial.UserBalances ubl on ubl.LogID=uba.SourceLogID
                WHERE     uba.UserID = @UserID
                          AND (uba.DateCreated BETWEEN @StartDate AND @EndDate)
                          AND uba.IdentifierType = 21 -- TransactionCodeItemID
                GROUP BY  uba.ToIdentifier,
            ubl.CurrencyConverterRateGroupID,
                        p.Title,
                        p.GeneratedID,
                        p.UserID
         UNION
          -- END bbaxter AHOY-183: Debit(s) paid by uPay code activation
         SELECT    ii.InvoiceItemID,
                            0 AS PaymentID,
                            0 AS PayoutID,
                            'L01' + CAST(ii.Identifier AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            ii.DateCreated,
              ii.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            ii.AmountToCharge,
                            ii.ItemTypeID,
                            0 AS AutoAccept,
                            CASE WHEN bl.BrokeredListingId IS NOT NULL THEN 1
                                 ELSE 0
                            END AS IsBrokered,
                            0 AS PaymentType,
                            p.Title,
                            p.GeneratedID,
                            p.UserID AS ShipperID,
                            'Shipper' AS [Role],
                            '' AS PayNumber,
                            COALESCE(ii.Note, '') AS Note,
                            COALESCE(ii.CurrencyID, 1) AS CurrencyID,
                            ii.InvoiceID,
              0 as TransactionCodeheld,
                            ii.Identifier,
                            'listing' AS TransactionType,
                            0 AS IsPackageMatch,
              0 AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      Financial.InvoiceItems ii
                            INNER JOIN Financial.Invoices i ON i.InvoiceID = ii.InvoiceID
                            INNER JOIN Marketplace.Listings p ON p.PackageID = ii.Identifier
                            LEFT JOIN Marketplace.BrokeredListings bl ON bl.BrokeredListingId = p.PackageID
                  WHERE     i.UserID = @UserID
              AND i.UserID = p.UserID
                            AND (ii.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND ii.ItemTypeID = 33 -- Auction Listing Fee
                  UNION
                  SELECT  t.InvoiceItemID,
              0 AS PaymentID,
              0 AS PayoutID,
              'BO1' + CAST(t.Identifier AS VARCHAR) AS Identifier,
                            0 AS PromotionID,
                            t.DateCreated,
              ii.CurrencyConverterRateGroupID as CurrencyConverterRateGroupID,
                            ii.AmountToCharge,
                            CASE WHEN ii22.InvoiceItemID IS NOT NULL THEN 22
                                 ELSE ii.ItemTypeID
                            END AS ItemTypeID,
                            0 AS AutoAccept,
                            0 AS IsBrokered,
                            0 AS PaymentType,
                            l.Title,
                            l.GeneratedID,
                            l.UserID AS ShipperID,
                            CASE WHEN ii.ItemTypeID IN (35, 37) THEN 'TSP'
                 ELSE 'Shipper' END AS [Role],
                            COALESCE(ii.PayNumber, '') AS PayNumber,
                            COALESCE(ii.Note, '') AS Note,
                            t.CurrencyID,
                            t.InvoiceID,
              0 as TransactionCodeheld,
                            t.Identifier AS NumIdentifier,
                            'bid' AS TransactionType,
                            NULL AS IsPackageMatch,
              0 AS IdentifierType,
              NULL as TransactionCodeActive
                  FROM      #InvoiceItemTemp t
                            INNER JOIN Financial.InvoiceItems ii ON t.InvoiceItemID = ii.InvoiceItemID
              LEFT JOIN Financial.InvoiceItems ii22 ON ii22.Identifier = ii.Identifier
                                   AND ii22.InvoiceID = ii.InvoiceID
                                   AND ii22.ItemTypeID = 22
                            INNER JOIN @Amount a ON t.Identifier = a.Identifier
                                                    AND t.DateCreated = a.DateCreated
                            INNER JOIN Marketplace.Bids b ON b.PackageMatchID = t.Identifier
                            INNER JOIN Marketplace.Listings l ON l.PackageID = b.PackageID
                  WHERE   ii.ItemTypeID IN (35, 36, 37, 38) -- LtlAdditionalCharge, ShipperLtlAdditionalCharge
                ) AS A
    WHERE @Identifier = 0 OR (A.NumIdentifier = @Identifier 
                  AND ((A.TransactionType = @TransactionType AND A.TransactionType IS NOT NULL) 
                     OR (A.IsPackageMatch = @IsPackageMatch AND A.IsPackageMatch IS NOT NULL)))
        ORDER BY DateCreated DESC,
                InvoiceItemID DESC
        
        SELECT  *
        FROM    ( SELECT    'BO1' + CAST(t.Identifier AS VARCHAR) AS Identifier,
                            t.DateCreated,
                            ii.ItemTypeID,
                            CASE WHEN ii.ItemTypeID = 22 AND leg2.TransactionCodeItemID IS NOT NULL THEN tci.Amount
                 ELSE ii.OriginalAmount
              END OriginalAmount,
              CASE WHEN ii.ItemTypeID = 22 AND leg2.TransactionCodeItemID IS NOT NULL THEN leg2.Amount
                 ELSE t.AmountToCharge
              END AmountToCharge,
                            ii.ItemID,
                            ii.PromotionID,
                            ( ii.AmountToCharge - ii.OriginalAmount ) AS PromotionAmount,
                            CASE WHEN ii.ItemTypeID = 1
                                      AND pm.AutoAccept = 1
                                      AND ii.OriginalAmount < pay.Amount
                                 THEN pay.Amount - ii.OriginalAmount
                                      - CASE WHEN ii.AmountToCharge - ii.OriginalAmount > 0
                                             THEN ii.AmountToCharge - ii.OriginalAmount
                                             ELSE 0
                                      + ( SELECT    COALESCE(SUM(AmountToCharge), 0)
                      FROM      Financial.InvoiceItems
                      WHERE     Identifier = ii.Identifier
                            AND InvoiceID = ii.InvoiceID
                            AND ItemTypeID = 15 
                            AND DateCreated > @TerrapassInclusive
                    )
                                        END
                                 WHEN ii.ItemTypeID = 2
                                      AND pm.AutoAccept = 1
                                      AND -ii.OriginalAmount < pay.Amount
                                 THEN pay.Amount + ii.OriginalAmount
                                      - CASE WHEN ii.AmountToCharge - ii.OriginalAmount < 0
                                             THEN ii.AmountToCharge - ii.OriginalAmount
                                             ELSE 0
                                        END
                                 WHEN pay.PaymentTypeID = 105 THEN pay.Amount
                                 ELSE 0
                            END AS Delinquent,
                            COALESCE(-ii2.AmountToCharge, 0) ShipperDeposit,
                            CASE WHEN ii.itemTypeID = 1
                                      AND ii.DateCreated < @CreditLaunchDate
                                 THEN 0
                                 WHEN ii2.AmountToCharge IS NULL
                                 THEN CASE WHEN bl.BrokeredListingId IS NOT NULL -- Brokered listing doesn't use credit
                                           THEN CASE WHEN pay.PaymentID IS NOT NULL 
                           THEN CASE WHEN ii.ItemTypeID = 1 THEN ii.AmountToCharge 
                                               - pay.Amount
                                               + ( SELECT    COALESCE(SUM(AmountToCharge), 0)
                                               FROM      Financial.InvoiceItems
                                               WHERE     Identifier = ii.Identifier
                                                 AND InvoiceID = ii.InvoiceID
                                                 AND ItemTypeID = 15 
                                                 AND DateCreated > @TerrapassInclusive
                                              )
                                 WHEN ii.ItemTypeID = 2 THEN ii.AmountToCharge 
                                               + pay.Amount
                                               - ( SELECT    COALESCE(SUM(AmountToCharge), 0)
                                               FROM      Financial.InvoiceItems
                                               WHERE     Identifier = ii.Identifier
                                                 AND InvoiceID = ii.InvoiceID
                                                 AND ItemTypeID = 15 
                                                 AND DateCreated > @TerrapassInclusive
                                              )
                                 ELSE 0 END 
                           ELSE ii.AmountToCharge END
                       WHEN pm.AutoAccept = 0
                                           THEN ii.AmountToCharge
                       -- pm.AutoAccept = 1
                                           ELSE CASE WHEN pay.PaymentID IS NOT NULL
                                                     THEN CASE WHEN ii.AmountToCharge > 0
                                                                    AND pay.Amount >= ii.AmountToCharge THEN 0
                                                               WHEN ii.AmountToCharge < 0
                                                                    AND pay.Amount >= -ii.AmountToCharge THEN 0
                                                               WHEN ii.AmountToCharge > 0 THEN ii.AmountToCharge - pay.Amount
                                                               ELSE ii.AmountToCharge + pay.Amount
                                                          END
                           --pay.PaymentID IS NULL
                                                     ELSE CASE WHEN ii.itemTypeID = 1
                                                                    AND ii.DateCreated > @CreditLaunchDate
                                                                    AND ( ii.DateCreated < @StartDateBINBug
                                                                          OR ii.DateCreated >= @EndDateBINBug
                                                                        ) THEN ii.AmountToCharge
                                                               ELSE 0
                                                           END
                                                END
                                      END
                                 WHEN ii2.AmountToCharge IS NOT NULL
                                 THEN CASE WHEN ii.ItemTypeID = 1
                                           THEN ii.AmountToCharge
                                                + ii2.AmountToCharge
                                                + ( SELECT    COALESCE(SUM(AmountToCharge), 0)
                                                    FROM      Financial.InvoiceItems
                                                    WHERE     Identifier = ii.Identifier
                                                            AND InvoiceID = ii.InvoiceID
                                                            AND (ItemTypeID IN ( 21, 22, 25, 26 ) OR (ItemTypeID = 15 AND DateCreated > @TerrapassInclusive))
                                                )
                                            WHEN ii.ItemTypeID = 2
                                            THEN ii.AmountToCharge
                                                - ii2.AmountToCharge
                                                - ( SELECT    COALESCE(SUM(AmountToCharge), 0)
                                                    FROM      Financial.InvoiceItems
                                                    WHERE     Identifier = ii.Identifier
                                                            AND InvoiceID = ii.InvoiceID
                                                            AND (ItemTypeID IN ( 23, 24 ) OR (ItemTypeID = 15 AND DateCreated > @TerrapassInclusive))
                                                )
                      -- ii.ItemTypeID NOT IN (1, 2)
                                            ELSE 0
                                    END
                 -- anything else
                                 ELSE 0
                            END AS AccountCredit,
                            0 AS Refund,
                            0 AS Fee,
                            ii.CurrencyID,
                            t.InvoiceID,
                            t.Identifier AS NumIdentifier,
                            'bid' AS TransactionType,
                            1 AS IsPackageMatch,
              CASE WHEN leg2.TransactionCodeItemID IS NOT NULL THEN 1
                 ELSE 0
              END IsBrokerPayThroughFirstLeg,
              0 AS IsBrokerPayThroughSecondLeg
                  FROM      #InvoiceItemTemp t
                            INNER JOIN Financial.InvoiceItems ii ON t.InvoiceItemID = ii.InvoiceItemID
              INNER JOIN Financial.Invoices i ON i.InvoiceID = ii.InvoiceID
              LEFT JOIN Financial.TransactionCodes tc ON tc.InvoiceItemID = ii.InvoiceItemID
              LEFT JOIN Financial.TransactionCodeItems tci ON tci.TransactionCodeID = tc.TransactionCodeID
                                      AND tci.UserID = i.UserID -- Transaction Code that belongs to the owner of InvoiceItems.ItemTypeID = 22
                            INNER JOIN Marketplace.Bids pm ON t.Identifier = pm.PackageMatchID
                            INNER JOIN Marketplace.Listings p ON p.PackageID = pm.PackageID
                            LEFT JOIN Financial.Payments pay ON pay.Identifier = t.Identifier
                                                              AND pay.UserID = @UserID
                            LEFT JOIN Financial.InvoiceItems ii2 ON t.Identifier = ii2.Identifier
                                                                   AND ii2.ItemTypeID = 10
                            LEFT JOIN Marketplace.BrokeredListings bl ON bl.BrokeredListingId = p.PackageID
              LEFT JOIN (SELECT tci2.TransactionCodeItemID,
                        tci2.Amount,
                        tci2.TransactionCodeID,
                        bl2.OriginalListingId
                     FROM Marketplace.BrokeredListings bl2
                      LEFT JOIN Marketplace.Listings bp ON bp.PackageID = bl2.BrokeredListingId
                      LEFT JOIN Marketplace.Bids bb ON bb.PackageID = bp.PackageID
                                       AND bb.Accepted = 1
                      LEFT JOIN Financial.TransactionCodeItems tci2 ON tci2.UserID = bb.UserID) leg2 ON leg2.TransactionCodeID = tc.TransactionCodeID -- If the listing was reposted and match and there's a split in the code for this carrier, then it's Broker Pay Through
                                                                AND leg2.OriginalListingId = p.PackageID -- Assume this listing is the original listing, then find out if it's reposted as a brokered shipment
                  WHERE     ii.ItemTypeID NOT IN ( 15, 16, 17, 29, 30 )
                  UNION
                  SELECT    'BO1' + CAST(ii.Identifier AS VARCHAR) AS Identifier,
                            DATEADD(mi, DATEDIFF(mi, 0, ii.DateCreated), 0) AS DateCreated,
                            oii22.ItemTypeID,
                            otci.Amount OriginalAmount,
                            otci.Amount AmountToCharge,
                            0 AS ItemID,
                            0 AS PromotionID,
                            0 AS PromotionAmount,
                            0 AS Delinquent,
                            0 AS ShipperDeposit,
                            0 AS AccountCredit,
                            0 AS Refund,
                            0 AS Fee,
                            COALESCE(otci.CurrencyID, 1) AS CurrencyID,
                            ii.InvoiceID,
                            ii.Identifier AS NumIdentifier,
                            'bid' AS TransactionType,
              1 AS IsPackageMatch,
              0 AS IsBrokerPayThroughFirstLeg,
              1 AS IsBrokerPayThroughSecondLeg
                  FROM      Financial.InvoiceItems ii
                            INNER JOIN Financial.Invoices i ON i.InvoiceID = ii.InvoiceID
              INNER JOIN Marketplace.Bids b ON b.PackageMatchID = ii.Identifier
              INNER JOIN Marketplace.Listings l ON l.PackageID = b.PackageID
              INNER JOIN Marketplace.BrokeredListings bl ON bl.BrokeredListingId = l.PackageID
              INNER JOIN Marketplace.Listings ol ON ol.PackageID = bl.OriginalListingId
              INNER JOIN Marketplace.Bids ob ON ob.PackageID = ol.PackageID
              INNER JOIN Financial.InvoiceItems oii22 ON oii22.Identifier = ob.PackageMatchID
              INNER JOIN Financial.TransactionCodes otc ON otc.InvoiceItemID = oii22.InvoiceItemID
              INNER JOIN Financial.TransactionCodeItems otci ON otci.TransactionCodeID = otc.TransactionCodeID
                                        AND otci.UserID = b.UserID
                  WHERE     i.UserID = @UserID
							AND (ii.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND ii.ItemTypeID IN ( 1 ) -- Shipper's Terrapass and Terrapass retraction
              AND ob.Accepted = 1
              AND oii22.ItemTypeID = 22
                  UNION
                  SELECT    'BO1' + CAST(ii.Identifier AS VARCHAR) AS Identifier,
                            DATEADD(mi, DATEDIFF(mi, 0, ii.DateCreated), 0) AS DateCreated,
                            ii.ItemTypeID,
                            ii.OriginalAmount,
                            ii.AmountToCharge,
                            ii.ItemID,
                            ii.PromotionID,
                            ( ii.AmountToCharge - ii.OriginalAmount ) AS PromotionAmount,
                            0 AS Delinquent,
                            0 AS ShipperDeposit,
                            0 AS AccountCredit,
                            0 AS Refund,
                            0 AS Fee,
                            COALESCE(ii.CurrencyID, 1) AS CurrencyID,
                            ii.InvoiceID,
                            ii.Identifier AS NumIdentifier,
                            'bid' AS TransactionType,
              1 AS IsPackageMatch,
              0 AS IsBrokerPayThroughFirstLeg,
              0 AS IsBrokerPayThroughSecondLeg
                  FROM      Financial.InvoiceItems ii
                            INNER JOIN Financial.Invoices i ON i.InvoiceID = ii.InvoiceID
                  WHERE     i.UserID = @UserID
                            AND (ii.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND ii.ItemTypeID IN ( 29, 30 ) -- Shipper's Terrapass and Terrapass retraction
                  UNION
                  SELECT    'BO1' + CAST(ii.Identifier AS VARCHAR) AS Identifier,
                            t.DateCreated,
                            ii.ItemTypeID,
                            ii.OriginalAmount,
                            ii.AmountToCharge,
                            ii.ItemID,
                            ii.PromotionID,
                            ( ii.AmountToCharge - ii.OriginalAmount ) AS PromotionAmount,
                            0 AS Delinquent,
                            0 AS ShipperDeposit,
                            0 AS AccountCredit,
                            0 AS Refund,
                            0 AS Fee,
                            COALESCE(ii.CurrencyID, 1) AS CurrencyID,
                            t.InvoiceID,
                            ii.Identifier AS NumIdentifier,
                            'bid' AS TransactionType,
                            1 AS IsPackageMatch,
              0 AS IsBrokerPayThroughFirstLeg,
              0 AS IsBrokerPayThroughSecondLeg
                  FROM      #InvoiceItemTemp t
              INNER JOIN Financial.InvoiceItems ii ON t.InvoiceItemID = ii.InvoiceItemID
                            INNER JOIN Financial.Invoices i ON i.InvoiceID = ii.InvoiceID
                  WHERE     i.UserID = @UserID
                            AND (ii.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND ii.ItemTypeID IN ( 15, 16 ) -- TSP's Terrapass and Terrapass retraction
                            AND ii.DateCreated > @TerrapassInclusive
                  UNION
                  SELECT    'BO1' + CAST(t.Identifier AS VARCHAR) AS Identifier,
                            DATEADD(mi, DATEDIFF(mi, 0, t.DateCreated), 0) AS DateCreated,
                            ii.ItemTypeID,
                            ii.OriginalAmount,
                            t.AmountToCharge,
                            ii.ItemID,
                            ii.PromotionID AS PromotionID,
                            ( ii.AmountToCharge - ii.OriginalAmount ) AS PromotionAmount,
                            0 AS Delinquent,
                            0 AS ShipperDeposit,
                            0 AS AccountCredit,
                            0 AS Refund,
                            0 AS Fee,
                            t.CurrencyID,
                            t.InvoiceID,
                            t.Identifier AS NumIdentifier,
                            'listing' AS TransactionType,
                            0 AS IsPackageMatch,
              0 AS IsBrokerPayThroughFirstLeg,
              0 AS IsBrokerPayThroughSecondLeg
                  FROM      #InvoiceItemTemp t
                            INNER JOIN Financial.InvoiceItems ii ON t.InvoiceItemID = ii.InvoiceItemID
                  WHERE     ii.ItemTypeID = 17
                  UNION
                  SELECT    'BO1' + CAST(ii.Identifier AS VARCHAR) AS Identifier,
                            DATEADD(mi, DATEDIFF(mi, 0, ref.DateCreated), 0) AS DateCreated,
                            ii.ItemTypeID,
                            -ii.OriginalAmount,
                            -ii.AmountToCharge,
                            ii.ItemID,
                            0 AS PromotionID,
                            0 AS PromotionAmount,
                            0 AS Delinquent,
                            0 AS ShipperDeposit,
                            0 AS AccountCredit,
                            1 AS Refund,
                            0 AS Fee,
                            COALESCE(pay.CurrencyID, 1) AS CurrencyID,
                            ii.InvoiceID,
                            ii.Identifier AS NumIdentifier,
                            'listing' AS TransactionType,
                            0 AS IsPackageMatch,
              0 AS IsBrokerPayThroughFirstLeg,
              0 AS IsBrokerPayThroughSecondLeg
                  FROM      Financial.InvoiceItems ii
                            INNER JOIN Financial.Invoices i ON ii.InvoiceID = i.InvoiceID
                            INNER JOIN Financial.Payments pay ON ii.Identifier = pay.Identifier
                            INNER JOIN Financial.Refunds ref ON ref.PaymentID = pay.PaymentID
                            INNER JOIN Marketplace.Listings p ON p.PackageID = ii.Identifier
                  WHERE     pay.userID = @UserID
                            AND i.UserID = pay.UserID
                            AND pay.typeID = 2 -- Upgrade refund
                            AND p.UserID = pay.UserID
                            AND (ii.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND ref.Status = 1
                  UNION
                  SELECT    'W01' + CAST(w.PayoutID AS VARCHAR) AS Identifier,
                            DATEADD(mi, DATEDIFF(mi, 0, w.DateCreated), 0) AS DateCreated,
                            -3 AS ItemTypeID,
                            -w.Amount AS OriginalAmount,
                            -w.Amount AS AmountToCharge,
                            w.PaymentTypeID AS ItemID,
                            0 AS PromotionID,
                            0 AS PromotionAmount,
                            0 AS Delinquent,
                            0 AS ShipperDeposit,
                            0 AS AccountCredit,
                            0 AS Refund,
                            -w.TransferFee AS Fee,
                            w.CurrencyID,
                            0 AS InvoiceID,
                            w.PayoutID,
                            'payout' AS TransactionType,
                            NULL AS IsPackageMatch,
              0 AS IsBrokerPayThroughFirstLeg,
              0 AS IsBrokerPayThroughSecondLeg
                  FROM      Financial.Payouts w
                  WHERE     w.UserID = @UserID
                            AND (w.DateCreated BETWEEN @StartDate AND @EndDate)
                            AND w.PayoutTypeID = 13 -- SafePay
                ) AS B
    WHERE @Identifier = 0 OR (B.NumIdentifier = @Identifier 
                  AND ((B.TransactionType = @TransactionType AND B.TransactionType IS NOT NULL) 
                     OR (B.IsPackageMatch = @IsPackageMatch AND B.IsPackageMatch IS NOT NULL)))
        ORDER BY Identifier,
                DateCreated

	DROP TABLE #InvoiceItemTemp;
  END
