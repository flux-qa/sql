USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[createPurchaseAdvisory]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[createPurchaseAdvisory]
--
-- 2/15/15 -- added lead days growth and to order growth calc
-- 12/16/15 -- added Peer Relationship to Items
-- 12/31/15 -- Fixed Negative ToOrders
-- 01/15/16 -- Put correct logic for %Templatable and deltaCost
-- 01/18/16 -- Added UMStock Update
-- 02/04/16 -- Redid logic of ToOrder and OpenToBuy
-- 02/06/16 -- added logic for Computing Projected Usage
-- 02/10/16--  Count# of Customers, format % Templatable
-- 02/24/16 -- Added 2 years ago usage
-- 03/08/16 -- Added a bunch of coalesce
-- 04/09/16 -- added UsageDays parameter
-- 05/03/16 -- added calc for Future Buys
-- 05/16/16 -- added logic to never have LeadDays + SafetyStock > 91 Days (in variable)
-- 09/07/16 -- Fixed Growth Calculations
-- 01/30/18 -- Updated Templatable % and $ Delta
-- 09/02/20 -- Changed Rounding for Stock Days to 1 Decimal Point
-- 03/28/23 -- max Open to Buy is 45 days X daily usage
-- 08/22/23 -- Added 1 day to @Today to include all of todays sales
@UsageDays      integer = 91,
@futureBuysFlag integer = 0,
@loginName      varchar(20) = ''

AS

DECLARE 
@FromDate DATE,
@ThruDate DATE,

@CompareDays integer = (@UsageDays -1),
@WorkDays INTEGER,
@Today DATE,
@TodayLess90 DATE,
@LastYear DATE,
@LastYearLess90 DATE,
@TwoYears DATE,
@TwoYearsLess90 DATE,
@MaxLeadDays integer = @UsageDays

DELETE FROM PURCHASEADVISORY WHERE loginName = @loginName

--set @WorkDays = dbo.CalculateNumberOfWorkDays(@UsageFrom, @UsageThru)

SET @Today = dateadd(dd, 1, getDate())
SET @FromDate = dateAdd(dd, -365, @Today)
SET @ThruDate = dateAdd(dd, @CompareDays, @fromDate)
SET @TodayLess90 = dateAdd(dd, -@CompareDays, @Today)
SET @LastYear = dateAdd(yy, -1, @Today)
SET @LastYearLess90 = dateAdd(dd, -@CompareDays, @LastYear)
SET @TwoYears = dateAdd(yy, -2, @Today)
SET @TwoYearsLess90 = dateAdd(dd, -@CompareDays, @TwoYears)

SET @WorkDays = DATEDIFF ( dd , @FromDate , @ThruDate)
IF @WorkDays < 1 SET @WorkDays = 1;



WITH w AS (SELECT I.ID AS ID, 1 AS BASVERSION, getDate() AS BASTIMESTAMP, 
    I.item, I.dim1, I.dim2, I.dim3, internalDescription,  
    I.UM, I.UMPer, I.UMAvailable, I.UMStock, I.UMUnshipped, I.UMOpenPO, ISNULL(UMUnshippedPO,0) as UMUNShippedPO, UMTemplatable, I.UMPocketWood,
    LFperUM,  i.avgCost, I.safetyStockInDays,idxAgressiveness, buyer,LFperBME, I.oldCode,
    estReceived, lastPO, round(UMLastPO,0) AS lastPOQty,
    I.leadTime, case when I.leadTime + I.SafetyStockInDays > @MaxLeadDays then @MaxLeadDays else I.leadTime + I.safetyStockInDays end as maxDaysToOrder,
    -- COMPUTE STOCKDAYS AS (STOCK + OPENPO - UNSHIPPED) / DAILY USAGE
    round((UMAvailable + UMOpenPO - ISNULL(UMUnshippedPO,0)) / (1.0 * isnull(usage,1.0) / @UsageDays) * 1.0,1) AS stockDays,
    -- DITTO FOR STOCK DAYS WITH GROWTH
    
    CASE WHEN USAGE IS NULL or USAGE < 1 THEN 0 ELSE
    round( (UMAvailable + UMOpenPO - ISNULL(UMUnshippedPO,0)) / (USAGE * 
        (CASE WHEN lastUsage > 0 AND USAGE  / @UsageDays  < 11.11 * currentUsage AND 
        COALESCE(noLastUsage,0) > 2 AND COALESCE(noCurrentUsage,0) > 2
        THEN (1.0 + (currentUsage - lastUsage) / lastUsage) ELSE 1 END / @UsageDays) * 1.0),1) END AS stockDaysGrowth,
    
    CASE WHEN isNull(lastUsage,0) > 0 AND isNull(USAGE,0) / @UsageDays  < 11.11 * isNull(currentUsage,0) AND 
        COALESCE(noLastUsage,0) > 2 AND COALESCE(noCurrentUsage,0) > 2
        THEN (1.0 + (isNull(currentUsage,0) - isNull(lastUsage,0)) / isNull(lastUsage,1)) ELSE 1 END AS growth,

    CASE WHEN oldUsage > 0 AND USAGE / @UsageDays  < 11.11 * usage AND 
        COALESCE(oldNoUsage,0) > 2 AND COALESCE(noUsage,0) > 2
        THEN (1.0 + (Usage - oldUsage) / oldUsage) ELSE 1 END AS oldGrowth,

    CASE WHEN USAGE = 0 OR USAGE IS NULL THEN COALESCE(currentUsage,0) ELSE USAGE END AS calcUsage,
    round(COALESCE(USAGE,0),0) AS USAGE, 
    round(COALESCE(USAGE,0) / @UsageDays * 1.0 ,0) AS dailyUsage,
    round(COALESCE(USAGE,0) / @UsageDays * 30.0 ,0) AS monthlyUsage,
  
    round(COALESCE(currentUsage, 0),0) AS currentUsage, 
    round(COALESCE(lastUsage,0),0) AS lastUsage,     
    coalesce(noUsage,0) as noUsage, 
    coalesce(maxUsage,0) as maxusage, 
    coalesce(noCurrentUsage,0) as noCurrentUsage, 
    coalesce(maxCurrentUsage,0) as maxCurrentUsage, 
    coalesce(noLastUsage,0) as noLastUsage, 
    coalesce(maxLastUsage,0) as maxLastUsage,

    round(coalesce(oldUsage,0),0) as oldUsage, 
    coalesce(oldNoUsage,0) as oldNoUsage, 
    coalesce(oldMaxUsage,0) as oldMaxUsage,

    CASE WHEN noUsage > 0 THEN round(USAGE / noUsage,0) ELSE 0 END AS avgUsage,
    CASE WHEN noCurrentUsage > 0 THEN round(currentUsage / noUsage,0) ELSE 0 END AS avgCurrentUsage,
    CASE WHEN noLastUsage > 0 THEN round(LastUsage / noLastUsage,0) ELSE 0 END AS avgLastUsage,
    CASE WHEN oldNoUsage > 0 THEN round(OldUsage / oldNoUsage,0) ELSE 0 END AS oldAvgUsage,
    
	pctTemplatable, deltaValueTemplatable, coalesce(numberOfCustomers,0) as numberOfCustomers, 
    coalesce(currentNumberOfCustomers,0) as currentNumberOfCustomers,
    coalesce(lastNumberOfCustomers,0) as lastNumberOfCustomers, coalesce(oldNumberOfCustomers,0) as oldNumberOfCustomers,
    oldPatternCode, patternCode, productCode


    FROM ITEMS I 
    LEFT OUTER JOIN CostAddons C ON C.ID = COALESCE(I.ps_CostAddOn_RID,1) 

    -- May 26, 2021 added left outer join to Purchase Lines to check to see if received
    LEFT OUTER JOIN (SELECT L.ob_Items_RID AS item, COALESCE(SUM(L.UMOrdered),0) UMCustOrder,
     isNull(sum(case when L.ps_purchaseLines_RID IS NULL OR PL.dateReceived is not null then 0 else L.UMOrdered end),0) as UMUnshippedPO
    FROM OrderLines L left outer join PurchaseLines PL on L.ps_PurchaseLines_RID = Pl.ID 
    WHERE L.dateShipped IS NULL AND L.WRD <> 'D' GROUP BY L.ob_Items_RID) 
    AS O ON I.ID = O.Item 

    LEFT OUTER JOIN (SELECT ob_Items_RID  AS item, floor(SUM(UMShipped)) AS USAGE,
    COUNT(*) AS noUsage, MAX(UMShipped) AS maxUsage, 
    COUNT(DISTINCT ob_Customers_RID) AS numberOfCustomers
    FROM OrderLines L
    INNER JOIN Orders O ON L.ob_Orders_RID = O.ID
    INNER JOIN Items I ON L.ob_Items_RID = I.ID 
    WHERE L.dateShipped BETWEEN  @FromDate AND @ThruDate AND L.WRD <> 'D'
    GROUP BY ob_Items_RID) Y ON I.ID = Y.item 

    LEFT OUTER JOIN (SELECT ob_Items_RID  AS item, floor(SUM(UMShipped)) currentUsage,
    COUNT(*) AS noCurrentUsage, MAX(UMShipped) AS maxCurrentUsage,
    COUNT(DISTINCT ob_Customers_RID) AS currentNumberOfCustomers
    FROM OrderLines L  INNER JOIN Items I ON L.ob_Items_RID = I.ID 
    INNER JOIN Orders O ON L.ob_Orders_RID = O.ID
    WHERE L.dateShipped BETWEEN  @TodayLess90 AND @Today AND L.WRD <> 'D'
    GROUP BY ob_Items_RID) CY ON I.ID = CY.item 

    LEFT OUTER JOIN (SELECT ob_Items_RID  AS item, floor(SUM(UMShipped)) lastUsage,
    COUNT(*) AS noLastUsage, MAX(UMShipped) AS maxLastUsage,
    COUNT(DISTINCT ob_Customers_RID) AS lastNumberOfCustomers
    FROM OrderLines L  INNER JOIN Items I ON L.ob_Items_RID = I.ID 
    INNER JOIN Orders O ON L.ob_Orders_RID = O.ID
    WHERE L.dateShipped BETWEEN  @LastYearLess90 AND @LastYear AND L.WRD <> 'D'
    GROUP BY ob_Items_RID) LY ON I.ID = LY.item 

    LEFT OUTER JOIN (SELECT ob_Items_RID  AS item, floor(SUM(UMShipped)) oldUsage,
    COUNT(*) AS oldNoUsage, MAX(UMShipped) AS oldMaxUsage,
    COUNT(DISTINCT ob_Customers_RID) AS oldNumberOfCustomers
    FROM OrderLines L  INNER JOIN Items I ON L.ob_Items_RID = I.ID 
    INNER JOIN Orders O ON L.ob_Orders_RID = O.ID
    WHERE L.dateShipped BETWEEN  @TwoYearsLess90 AND @TwoYears AND L.WRD <> 'D'
    GROUP BY ob_Items_RID) OY ON I.ID = OY.item 

    LEFT OUTER JOIN (SELECT L.ob_Items_RID AS item, SUM(quantityOrdered) AS UMLastPO, 
    MIN(estReceivedDate) AS estReceived, MAX(P.ID) AS lastPO 
    FROM PurchaseLines L INNER JOIN PurchaseOrders P ON L.ob_PurchaseOrders_RID = P.ID 
    WHERE L.status <> 'C' AND P.dateSubmitted is NOT null
    GROUP BY L.ob_Items_RID) AS PO ON PO.item = I.ID 


    where (I.serviceItem IS NULL or I.serviceItem = 0)

)


INSERT INTO PURCHASEADVISORY (ID, BASVERSION, BASTIMESTAMP, loginName, itemID,
    item, dim1, dim2, dim3, internalDescription, UM, UMPer, UMAvailable, UMStock,
    UMUnshipped, UMOpenPO, UMTemplatable, UMPocketWood, LFperUM, LFperBME,
    avgCost, safetyStockInDays, idxAgressiveness, buyer, oldcode, estReceived, lastPO,
    lastPOQty, leadTime, stockDays, stockDaysGrowth, stockDaysTemplatable, openToBuy, toOrder, 
    openToBuyGrowth, toOrderGrowth, momentum, growth, 
    monthlyUsage, dailyUsage, USAGE, noUsage, maxUsage, avgUsage,
    currentUsage,  noCurrentUsage, maxCurrentUsage, avgCurrentUsage,
    lastUsage, noLastUsage, maxLastUsage, avgLastUsage, 
    ps_Items_REN, ps_Items_RID, ps_Items_RMA, pctTemplatable, 
    deltaValueTemplatable, ruleUsed, pctTemplatableFormatted, 
    numberOfCustomers, currentNumberOfCustomers, lastNumberOfCustomers,
    oldUsage, oldAvgUsage, oldNoUsage, oldMaxUsage, oldNumberOfCustomers,
    oldRuleUsed, oldGrowth, toBuyFutureBuys, oldPatternCode, productCode, patternCode

)

    SELECT next value for PA_SEQ, 1, getDate(), @loginName, ID, item, dim1, dim2, dim3, internalDescription,  
    LEFT(UM,3) AS UM, UMPer, UMAvailable, UMStock,
    UMUnshipped,
    case when UMOpenPO - ISNULL(UMUnshippedPO,0) < 0 then 0 else UMOpenPO - ISNULL(UMUnshippedPO,0) end, 
    UMTemplatable, UMPocketWood,
/*
    case when UMAvailable = 0 then NULL else UMAvailable end as UMAvailable, 
    case when UMUnshipped = 0 then NULL else UMUnshipped end as UMUnshipped, 
    case when UMOpenPO = 0 then NULL else UMOpenPO end as UMOpenPO, 
    case when UMTemplatable = 0 then NULL else UMTemplatable end as UMTemplatable, 
    case when UMPocketWood = 0 then NULl else UMPocketWood end as UMPocketWood,
*/
    LFperUM,  LFperBME, avgCost, 
    CASE WHEN safetyStockInDays < 0 THEN NULL ELSE safetyStockInDays END AS safetyStockInDays, 
    idxAgressiveness, buyer, oldCode,
    estReceived, lastPO, lastPOQty,
    leadTime, stockDays, stockDaysGrowth, Round(stockDays * pctTemplatable,0),
    -- IF STOCK <= LEAD ORDER LEAD * DAILY USAGE
    -- IF STOCK - LEAD >= LEAD ORDER 0
    -- ELSE (LEAD - (STOCK - LEAD) * DAILY USAGE
    ROUND(CASE WHEN stockDays <= maxDaysToOrder  THEN maxDaysToOrder * (USAGE / @UsageDays * 1.0)
    WHEN stockdays - maxDaysToOrder >= maxDaysToOrder THEN 0
    ELSE ( maxDaysToorder - (stockDays - maxDaysToOrder))  * (USAGE / @UsageDays * 1.0 ) END,0) AS openToBuy,
 
    CASE WHEN USAGE = 0 OR USAGE IS NULL OR stockDays - (leadTime + safetyStockInDays) = 0 THEN 999 
        ELSE stockDays - (leadTime + safetyStockInDays) END AS toOrder,


    -- DO SAME FOR GROWTH AS I DID FOR OPENTOBUY ABOVE
    -- IF STOCK <= LEAD ORDER LEAD * DAILY USAGE
    -- IF STOCK - LEAD >= LEAD ORDER 0
    -- ELSE (LEAD - (STOCK - LEAD) * DAILY USAGE
    ROUND(CASE WHEN stockDaysGrowth < maxDaysToOrder  THEN maxDaysToOrder * (USAGE * growth / @UsageDays * 1.0)
    WHEN stockdaysGrowth - maxDaysToorder >= maxDaysToOrder THEN 0
    ELSE ( maxDaysToOrder - (stockDaysGrowth - maxDaysToOrder))  * (USAGE * growth / @UsageDays * 1.0) END,0) AS openToBuyGrowth,

    CASE WHEN USAGE = 0 OR USAGE IS NULL OR stockDays - (leadTime + safetyStockInDays) = 0 OR growth = 0 THEN 999 
        WHEN round(stockDaysGrowth - (leadTime + safetyStockInDays),0) < -999 then -999
        WHEN round(stockDaysGrowth - (leadTime + safetyStockInDays),0) > 999 then 999
        ELSE round(stockDaysGrowth - (leadTime + safetyStockInDays),0) END AS toOrderGrowth,

    CASE WHEN lastUsage = 0 AND currentUsage = 0 THEN 'N/A'
         WHEN lastUsage = 0 AND currentUsage > 0 THEN 'NEW'
         WHEN lastUsage > 0 AND currentUsage = 0 THEN 'DEAD'
         WHEN lastUsage > 0 AND lastUsage * 100 < (currentUsage - lastUsage) THEN '999'
         WHEN round(100 * (currentUsage - lastUsage) / lastUsage,0) < -999 then '-999%'
         WHEN round(100 * (currentUsage - lastUsage) / lastUsage,0) > 999 then '999%'         
         ELSE CAST (round(100 * (currentUsage - lastUsage) / lastUsage,0) AS CHAR(4)) + '%' END AS momentum,
    growth,

    monthlyUsage, dailyUsage, USAGE, noUsage, 
    CASE WHEN USAGE = 0 THEN 0 ELSE round(100.0 * maxUsage / USAGE,0) END, 
    avgUsage, currentUsage,  noCurrentUsage, 
    CASE WHEN currentUsage = 0 THEN 0 ELSE round(100.0 * maxCurrentUsage / currentUsage,0) END, 
    avgCurrentUsage, lastUsage, noLastUsage, 
    CASE WHEN lastUsage = 0 THEN 0 ELSE round(100.0 * maxLastUsage / lastUsage,0) END,  
    avgLastUsage, 'Items', ID, 'ps_PurchaseAdvisory',
	pctTemplatable, deltaValueTemplatable,

	-- COMPUTE THE RULE USED FROM JOSH'S INSTRUCTIONS
	--
    CASE
        WHEN idxAgressiveness < 3 THEN 'Idx<3'    

        -- NO SALES IN ANY PREVIOUS PERIOD -- NEW ITEM
        WHEN USAGE = 0 AND lastUsage = 0 AND currentUsage > 0 AND idxAgressiveness > 4 THEN 'New Idx>4'
        WHEN USAGE = 0 AND lastUsage = 0 AND currentUsage > 0 AND idxAgressiveness > 2 AND idxAgressiveness < 5 THEN 'New Idx3-4'

        -- DEAD ITEM
        WHEN  currentUsage = 0 THEN 'DEAD'

        -- LOW COUNT if not atleast 4 sales in each period
        WHEN noUsage < 4 OR nolastUsage < 4 OR noCurrentUsage < 4 THEN 'LowCount'

        -- BIG FISH if ANY of 3 periods has max > total sales
        WHEN maxUsage * 2 > USAGE OR maxLastUsage * 2 > lastUsage OR maxCurrentUsage * 2 > currentUsage THEN 'BigFish'


        -- NORMAL -- SALES IN ALL 3 PERIODS
        WHEN USAGE > 0 AND lastUsage > 0 AND currentUsage > 0 AND idxAgressiveness > 5 AND growth > 1 THEN 'Idx>5 +G'
        WHEN USAGE > 0 AND lastUsage > 0 AND currentUsage > 0 AND idxAgressiveness > 5 AND growth <= 1 THEN 'Idx>5 -G'

        WHEN USAGE > 0 AND lastUsage > 0 AND currentUsage > 0 AND idxAgressiveness = 5 AND growth > 1 THEN 'Idx=5 +G'
        WHEN USAGE > 0 AND lastUsage > 0 AND currentUsage > 0 AND idxAgressiveness = 5 AND growth <= 1 THEN 'Idx=5 -G'

        WHEN USAGE > 0 AND lastUsage > 0 AND currentUsage > 0 AND idxAgressiveness > 2 AND idxAgressiveness < 5 AND growth > 1 THEN 'Idx3-4 +G'
        WHEN USAGE > 0 AND lastUsage > 0 AND currentUsage > 0 AND idxAgressiveness > 2 AND idxAgressiveness < 5 AND growth <= 1 THEN 'Idx3-4 -G'

            
        ELSE 'UnKnown'	
    END, 
    CASE WHEN pctTemplatable = 1 THEN '' 
        ELSE Format(Round(100 * pctTemplatable,0),'###') + '%' END, 
    numberOfCustomers, currentNumberOfCustomers, lastNumberOfCustomers,
    oldUsage, oldAvgUsage, oldNoUsage, oldMaxUsage, oldNumberOfCustomers,



	-- COMPUTE THE RULE USED USING oldUsage vs. LastUsage
	--
    CASE
        WHEN idxAgressiveness < 3 THEN 'Idx<3'    

        -- NO SALES IN ANY PREVIOUS PERIOD -- NEW ITEM
        WHEN USAGE = 0 AND lastUsage = 0 AND currentUsage > 0 AND idxAgressiveness > 4 THEN 'New Idx>4'
        WHEN USAGE = 0 AND lastUsage = 0 AND currentUsage > 0 AND idxAgressiveness > 2 AND idxAgressiveness < 5 THEN 'New Idx3-4'

        -- DEAD ITEM
        WHEN  currentUsage = 0 THEN 'DEAD'

        -- LOW COUNT if not atleast 4 sales in each period
        WHEN noUsage < 4 OR nolastUsage < 4 OR noCurrentUsage < 4 or oldNoUsage < 4 THEN 'LowCount'

        -- BIG FISH if ANY of 3 periods has max > total sales
        WHEN maxUsage * 2 > USAGE OR maxLastUsage * 2 > lastUsage OR maxCurrentUsage * 2 > currentUsage 
            or oldMaxUsage * 2 > oldUsage THEN 'BigFish'


        -- NORMAL -- SALES IN ALL 3 PERIODS
        WHEN USAGE > 0 AND oldUsage > 0 AND currentUsage > 0 AND idxAgressiveness > 5 AND growth > 1 THEN 'Idx>5 +G'
        WHEN USAGE > 0 AND oldUsage > 0 AND currentUsage > 0 AND idxAgressiveness > 5 AND growth <= 1 THEN 'Idx>5 -G'

        WHEN USAGE > 0 AND oldUsage > 0 AND currentUsage > 0 AND idxAgressiveness = 5 AND growth > 1 THEN 'Idx=5 +G'
        WHEN USAGE > 0 AND oldUsage > 0 AND currentUsage > 0 AND idxAgressiveness = 5 AND growth <= 1 THEN 'Idx=5 -G'

        WHEN USAGE > 0 AND oldUsage > 0 AND currentUsage > 0 AND idxAgressiveness > 2 AND idxAgressiveness < 5 AND growth > 1 THEN 'Idx3-4 +G'
        WHEN USAGE > 0 AND oldUsage > 0 AND currentUsage > 0 AND idxAgressiveness > 2 AND idxAgressiveness < 5 AND growth <= 1 THEN 'Idx3-4 -G'

            
        ELSE 'UnKnown'
    END , oldGrowth, 
        case when usage - (UMAvailable + UMPocketWood + UMOpenPO - ISNULL(UMUnshippedPO,0)) < 0 then 0 else 
Round(usage - (UMAvailable + UMPocketWood + UMOpenPO - ISNULL(UMUnshippedPO,0)),0) end, oldPatternCode, productCode, patternCode
     

    FROM W
    WHERE LEFT(oldCode,1)<> '|'


/* 
*   -- Fix the Growth to be no more then +/ 999 pct
*   -- Then recompute stockDaysGrowth and Usage Calcs 
*/

update PurchaseAdvisory
set growth = CASE WHEN ruleUsed = 'BigFish' OR ruleUsed = 'LowCount' or ruleUsed = 'Dead' then 1
when growth > 10 then 10
when growth > 0 and growth < 0.10 then 0.10  else growth end,

oldGrowth = CASE WHEN ruleUsed = 'BigFish' OR ruleUsed = 'LowCount' or ruleUsed = 'Dead' then 1
when oldGrowth > 10 then 10
when oldGrowth > 0 and oldGrowth < 0.10 then 0.10 else oldGrowth end

where loginName = @loginName

update purchaseAdvisory set stockdaysGrowth = stockDays where loginName = @loginName
update purchaseAdvisory set stockDaysGrowth = round( (UMAvailable + UMOpenPO) / (projectedUsage / @UsageDays * 1.0), 1)
where loginName = @loginName and projectedUsage > 1

update purchaseAdvisory set openToBuyGrowth = ROUND(
CASE WHEN stockDaysGrowth < (leadTime + safetyStockInDays)  THEN (leadTime + safetyStockInDays) * (projectedUsage / @UsageDays * 1.0)
    WHEN stockdaysGrowth - (leadTime + safetyStockInDays) >= (leadTime + safetyStockInDays) THEN 0
    ELSE ((leadTime + safetyStockInDays) - (stockDaysGrowth - (leadTime + safetyStockInDays)))  * (projectedUsage / @UsageDays * 1.0) END,0) 
where loginName = @loginName




    -- NEXT, UPDATE THE PROJECTED GROWTH IN THE P/A FILE
UPDATE PURCHASEADVISORY SET 
    toOrder = case when toOrder < -999 then -999
    when toOrder > 999 then 999
    else toOrder end,

    projectedUsage =
        CASE WHEN ruleUsed = 'BigFish' OR ruleUsed = 'LowCount' or ruleUsed = 'Dead' THEN
            
            -- IF IDX > 5 THEN USE HIGHEST OF 3
            CASE WHEN idxAgressiveness  > 5 THEN 
                CASE WHEN USAGE > lastUsage AND USAGE > currentUsage THEN USAGE
                     WHEN lastUsage > currentUsage THEN lastUsage
                     ELSE currentUsage
                     END
                WHEN IdxAgressiveness = 5 THEN round((USAGE + lastUsage + currentUsage) * 0.334,0)
                ELSE 
                    -- AVERAGE THE BOTTOM 2
                    CASE WHEN USAGE > lastUsage AND USAGE > currentUsage THEN round((lastUsage + currentUsage) / 2,0)
                     WHEN lastUsage > currentUsage THEN round((currentUsage + usage) * 0.5,0)
                     ELSE round((lastUsage + usage) /2,0)
                     END
            END
        WHEN ruleUsed = 'Idx>5 +G'      THEN round(USAGE * growth,0)
        WHEN ruleUsed = 'Idx>5 -G'      THEN round(USAGE + (USAGE * (growth - 1) * 0.50),0)
        WHEN ruleUsed = 'Idx=5 +G'      THEN round(USAGE + (USAGE * (growth - 1) * 0.10),0) 
        WHEN ruleUsed = 'Idx=5 -G'      THEN round(USAGE + (Usage * (growth - 1) * 0.75),0)              
        WHEN ruleUsed = 'Idx3-4 +G'     THEN round(USAGE,0)                              
        WHEN ruleUsed = 'Idx3-4 -G'     THEN round(USAGE * growth,0)
        WHEN ruleUsed = 'Idx<3'         THEN 0
        WHEN ruleUsed = 'New Idx>4'     THEN currentUsage
        WHEN ruleUsed = 'New Idx3-4'    THEN round(currentUsage / 2,0)
        ELSE 0

        END, 

        -- NOW THE SAME THING FOR THE OLD RULE
        oldProjectedUsage = 

        CASE WHEN oldRuleUsed = 'BigFish' OR oldRuleUsed = 'LowCount'THEN
            
            CASE WHEN idxAgressiveness  > 5 THEN 
                CASE WHEN USAGE > oldUsage  THEN USAGE
                     ELSE oldUsage
                     END
                WHEN IdxAgressiveness = 5 THEN round((USAGE + oldUsage) / 2,0)
                ELSE 
                    CASE WHEN USAGE < oldUsage THEN USAGE
                     ELSE oldUsage
                     END
            END
        WHEN OldruleUsed = 'Idx>5 +G'      THEN round(USAGE * oldgrowth,0)
        WHEN OldruleUsed = 'Idx>5 -G'      THEN round(USAGE + (USAGE * (oldgrowth - 1) / 2),0)
        WHEN OldruleUsed = 'Idx=5 +G'      THEN round(USAGE + (USAGE * (oldgrowth - 1) / 2),0)
        WHEN OldruleUsed = 'Idx=5 -G'      THEN round(USAGE * oldgrowth,0)
        WHEN OldruleUsed = 'Idx3-4 +G'     THEN round(USAGE + (USAGE * (oldgrowth - 1) / 3),0)
        WHEN OldruleUsed = 'Idx3-4 -G'     THEN round(USAGE * oldgrowth,0)
        WHEN OldruleUsed = 'Idx<3'         THEN 0
        WHEN OldruleUsed = 'New Idx>4'     THEN currentUsage
        WHEN OldruleUsed = 'New Idx3-4'    THEN round(currentUsage / 2,0)
        WHEN OldruleUsed = 'Dead'          THEN USAGE
        ELSE 0

        END

where loginName = @loginName

        -- COMPUTE STOCK DAYS GROWTH
/*
*   Compute StockDaysGrowth
*   (Stock / Daily Usage) and Stock = Stock + Open POs - Unshipped
*/

update purchaseAdvisory set stockdaysGrowth = stockDays where loginName = @loginName
update purchaseAdvisory set stockDaysGrowth = round( (UMAvailable + UMOpenPO ) / (projectedUsage / @UsageDays * 1.0), 1)
where loginName = @loginName and projectedUsage > 1

    -- FINALLY COMPUTE THE openToBuyGrowth and toOrderGrowth
    UPDATE PURCHASEADVISORY SET 
        openToBuyGrowth = ROUND(
            CASE WHEN (leadTime + safetyStockInDays) > @UsageDays THEN @UsageDays ELSE (leadTime + safetyStockInDays) END 
             * 2.0 *  (projectedUsage / @UsageDays)   - (UMAvailable + UMOpenPO) ,0),

    toOrderGrowth = CASE WHEN projectedUsage = 0 OR projectedUsage IS NULL THEN 999 
        WHEN round(stockDaysGrowth - (leadTime + safetyStockInDays),0) > 999 then 999
        WHEN round(stockDaysGrowth - (leadTime + safetyStockInDays),0) < -999 then -999
        ELSE round(stockDaysGrowth - (leadTime + safetyStockInDays),0) END
where loginName = @loginName


-- DO NOT PURCHASE ANYTHING WITH MORE THAN 45 DAYS OF STOCK --
Update PurchaseAdvisory set openToBuyGrowth = 0 where toOrderGrowth > 44
-- IF NEGATIVE DAYS TO PURCHASE CAP THE OPEN TO BUY GROWTH AS LOWER OF OTBG OR 45 * DAILY USAGE
Update PurchaseAdvisory set openToBuyGrowth = 45 * dailyUsage 
	where toOrderGrowth < 1 and  openToBuyGrowth > 45 * dailyUsage
-- if 1 to 44 days till need to purchase cap as min of OTBG or 45 minus days left * daily Usage	
Update PurchaseAdvisory set openToBuyGrowth = dailyUsage * (45 - toOrderGrowth) 
	where toOrderGrowth > 0 and toOrderGrowth < 45 and openToBuyGrowth > dailyUsage * (45 - toOrderGrowth)


Update PurchaseAdvisory set openToBuyGrowth = 0 where loginName = @loginName AND openToBuyGrowth < 0


-- CAP THE PROJECTED USAGE TO 200% OF USAGE IF GROWTH > 50% AND NEXT 91 DAYS LAST YEAR > (LAST 91 DAYS THIS YEAR) / 2
-- NEXT 91 DAYS = USAGE LAST 91 DAYS = LASTUSAGE
Update PurchaseAdvisory set ProjectedUsage = Usage * 2
    where loginName = @loginName and projectedUsage > 0 and usage > 0 and growth > 1.5 and usage * 2.0  > lastUsage
    and projectedUsage > usage * 2


-- IF COMING FROM FUTURE BUYS THEN COMPUTE OpenToBuyGrown based on the Usage Days
IF @FutureBuysFlag = 1 
Update PurchaseAdvisory set OpenToBuyGrowth =  
    CASE WHEN (Usage) > (UMAvailable + UMOpenPO) THEN ROUND((Usage) - (UMAvailable + UMOpenPO),0)
--    CASE WHEN (projectedUsage) > (UMAvailable + UMOpenPO) THEN ROUND((projectedUsage) - (UMAvailable + UMOpenPO),0)
    else 0 end
    where loginName = @loginName
    
    
update PurchaseAdvisory set pctTemplatable = T.templatablePct, deltaValueTemplatable = deltaValue
from PurchaseAdvisory P inner join TemplatableInventory T on P.ID = T.ID
where loginName = @loginName
GO
