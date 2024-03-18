USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ComputeQuoteCost]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ComputeQuoteCost]    
-- 
-- LAST CHANGE 10/13/16
--

    @quoteID        INTEGER,
    @Item	        INTEGER,
    @NumbSource     INTEGER,
    @NumbTarget     INTEGER,
    @WRD            CHAR(1),
    @CustomerQty    INTEGER,
    @CustomerUM     CHAR(3),
    @TallyUM        INTEGER,
    @Per            INTEGER,
    @CustLFtoUM     DECIMAL(12,4),
    @WholeUnits     INTEGER,
    @Pickup         INTEGER


AS

DECLARE


    @TallyCost      Money,
    @SourceCost     Money,
    @TargetCost     Money,
    @AvgCost        Money,
    @OverHeadCost   Money,
    @FreightCost    Money,
    @ProjectedCost  Money,
    @SuggestedPrice Money,
    @NetCost        Money,

    @CostAddOn      FLOAT,
    @CostCode       INTEGER,
    @GrossPct       FLOAT,
    @MinProfit      FLOAT,
    @ProfitDollars  FLOAT,
    @SourceAddon    FLOAT = 0,
    @TargetAddon    FLOAT = 0,
    @TotalLF	    INTEGER,
    @stdTripCost    DECIMAL(10,4),
    @TrailerBME	    INTEGER,
    @LFperBME	    FLOAT,
    @UMPer          INTEGER,
    @LFperUM         FLOAT,
    @POCost         FLOAT,
    @MAX_ID         INTEGER
    

SET @TargetCost = 0
SET @SourceCost = 0
SET @OverheadCost = 0
SET @ProjectedCost = 0
SET @FreightCost = 0
SET @TallyCost = 0

-- READ CONSTANTS AND CONVERSIONS FROM THE INVENTORY FILE    
SELECT @AvgCost = AvgCost ,  @CostCode = ps_CostAddOn_RID,
	@LFperBME = LFperBME, @LFperUM = LFperUM, @UMPer = COALESCE(UMPer,0) 
	FROM Items WHERE Item = @Item

	
-- READ CONSTANTS FROM THE CONTSTANT FILE	
SELECT @StdTripCost = STDTripCost, @TrailerBME = TrailerLoadBME 
	FROM Constants WHERE keyField = 1	

-- UPDATE THE @StdTripCost FROM THE CUSTOMER SECTOR
select @StdTripCost = coalesce(truckCost, @StdTripCost)
    from SECTORS S 
        inner join CUSTOMERS C on S.ID = C.ps_Sector_RID
        inner join QUOTES Q on Q.ob_Customers_RID = C.ID
    where Q.ID = @QuoteID

-- MAKE SURE WE DON'T DIVIDE BY ZERO
IF @CustomerQty = 0 SET @CustomerQty = 1000
IF @TrailerBME = 0 SET @TrailerBME = 12500
IF @UMPer = 0 SET @UMPer = 1000

-- IF THERE IS NOT A VALID COST ADDON CODE IN THE ITEM , DEFAULT TO THE DEFAULT VALUE
IF @CostCode IS NULL OR @CostCode = 0 SET @CostCode = 1

-- READ THE COSTS FOR THIS ITEM FROM THE COST ADDON FILE
-- REMOVED THE PER AND CUSTOMER QTY DIVISORS ON 10/7 TO FIX CONVERTING BETWEEN UMS
SELECT 	@CostAddOn = CASE WHEN @WRD = 'D' THEN COALESCE(directCostAddOn,0) 
            WHEN @WRD = 'R' THEN COALESCE(reloadCostAddOn,0)
            ELSE COALESCE(warehouseCostAddOn,0) END, 
		@GrossPct = CASE WHEN @WRD = 'D' THEN COALESCE(directProfitPct,0) 
            WHEN @WRD = 'R' THEN COALESCE(reloadProfitPct,0)
            ELSE COALESCE(warehouseProfitPct,0) END, 
		@MinProfit = COALESCE(MinimumProfit,0),
        @ProfitDollars = COALESCE(profitDollars,0),
		@SourceAddon = sourceUnitAddon,
		@TargetAddon = AssignedUnitAddon
  FROM CostAddOns WHERE ID = @CostCode

/*
--READ PURCHASE LINE COST ASSUMING THIS QUOTE IS TIED TO A VENDOR PO
-- ADD THE WEIGHTED FREIGHT AND MISC CHARGE (BY LF) TO THE COST
select  @POCost = cast (100 * 
    ((1.0 * L.LFOrdered / T.totalLFOrdered * P.freight / L.quantityOrdered * L.costPer) + 
    (1.0 * L.LFOrdered / T.totalLFOrdered * P.MiscCharges / L.quantityOrdered * L.costPer) + L.cost + 
    coalesce(z.avgCost,0)) as int) / 100.0
    from purchaseLines L inner join PurchaseOrder P on L.PONumber = P.PONumber
    inner join (select PONumber, sum(LFOrdered) as totalLFOrdered 
        from PurchaseLines group by PONumber) as T on L.PONumber = T.PONumber
    
    -- IF THIS IS A CONTRACTOR PO THEN IT HAS AN ORDER LINE, 
    -- ALSO ADD THE AVG COST FROM THE ITEM BEING SENT
    left outer join (select L.orderNumber, L.lineNumber, I.avgCost 
        from Items I inner join OrderLines L on I.item = L.item) as Z 
        on Z.orderNumber = L.ourSalesOrder and Z.lineNumber = L.ourSalesLine

    inner join quotes Q on Q.VendorPONumber = L.PONumber and Q.VendorPOLine = L.lineNumber
    where Q.recID = @RECID and L.costPer > 0 and L.quantityOrdered > 0 and L.cost > 0

if @POCost is not Null and @POCost > 0 set @AvgCost = @POCost
*/
-- CHANGED ON 5/21/14 TO CONVERT BY PER AND CONVERSION FACTORS
SET @ProjectedCost = @AvgCost *  @LFperUM * @Per / (@UMper * @CustLFtoUM) 

SET @OverHeadCost = @CostAddon * @per / @customerQty 
SET @SourceCost =  @NumbSource * @SourceAddon * @per / @customerQty
SET @TargetCost =  @NumbTarget * @TargetAddon * @per / @customerQty

-- IF WHOLE UNITS OR RELOAD THEN THERE IS NO SOURCE COST
IF @WholeUnits > 0 OR @WRD = 'R' SET @SourceCost = 0

-- IF DIRECT THEN THERE IS NO TARGET COST
IF @WRD = 'D' SET @TargetCost = 0

SELECT @TotalLF = COALESCE(SUM(length * pieces),0), 
    @tallyCost = @ProjectedCost * COALESCE(SUM(costDeltaPct),0) / 100.0
    FROM quoteTally WHERE ob_Quotes_RID = @quoteID

-- CHANGED 03/25/15 TO USE PARAMETERS INTEAD OF LOOKING UP TALLY QTY IN FILE
IF @TotalLF > 0 AND @TallyUM > 0 
    SET @FreightCost = @stdTripCost * (@TotalLF / @LFPerBME) / @TrailerBME * @per / @tallyUM

-- IF PICKUP THEN NO FREIGHT COST - 02/22/10
IF @Pickup = 1 SET @FreightCost = 0

-- ADD THE PROFIT PERCENT
SET @SuggestedPrice = floor(100 * (@ProjectedCost + @TallyCost) + (@ProjectedCost  + @TallyCost)  * @GrossPct) / 100.0 
-- ADD THE NON-MARKUP COSTS AND ANY FIXED PROFIT $
SET @SuggestedPrice = @SuggestedPrice + @freightCost + @OverheadCost + @SourceCost + @TargetCost

-- ROUND TO NEAREST PENNY
SET @SuggestedPrice = floor(@SuggestedPrice * 100) / 100.0
SET @ProjectedCost = Floor((@ProjectedCost + @OverheadCost + @FreightCost + @SourceCost + 
    @TargetCost + @TallyCost ) * 100) / 100.0
-- IF SOLD BY 1000, ROUND TO NEAREST DOLLAR

-- NET COST IS COST - FREIGHT
SET @NetCost = Floor((@ProjectedCost - @FreightCost) * 100) / 100.0


IF @PER = 1000 BEGIN
	SET @SuggestedPrice = floor(@SuggestedPrice + 0.95)
	SET @ProjectedCost = floor(@ProjectedCost + 0.95)
    set @NetCost = floor(@NetCost + 0.95)
END

--set @mktCost = @MktCost * @LFtoUM * @Per / (@CustLFtoUM * @UMPer)
SET @avgCost = @AvgCost * @LFperUM * @Per / (@CustLFtoUM * @UMPer)


-- MAKE SURE WE ARE NOT BELOW MINIMUM PROFIT
--if @customerQty * (@suggestedPrice - @ProjectedCost) / @UMPer < @MinProfit
--    set @SuggestedPrice = (@MinProfit + @ProjectedCost) / @CustomerQty * @UMPer



SET @freightCost = round(@FreightCost,2)
SET @tallyCost = round(@TallyCost,2)
SET @targetCost = round(@TargetCost,2)
SET @sourceCost = round(@SourceCost,2)
SET @overheadCost = round(@OverheadCost,2)
SET @projectedCost = round(@ProjectedCost,2)
SET @avgCost = round(@AvgCost,2)
SET @suggestedPrice = round(@SuggestedPrice,2)

UPDATE QUOTECOSTS
    SET freightCost = @FreightCost,
    tallyCost       = @tallyCost,
    targetCost      = @targetCost,
    sourceCost      = @sourceCost,
    overheadCost    = @OverheadCost,
    projectedCost   = @ProjectedCost,
    avgCost         = @AvgCost,
    suggestedPrice  = @suggestedPrice,
    tallyUM	    = @TallyUM,
    lastChange	    = getDate(),
    netCost         = @NetCost

WHERE ID = @QuoteID

INSERT INTO QUOTECOSTLOGS
([ID], [BASVERSION], [BASTIMESTAMP], 
[suggestedPrice], [tallyUM], [numbTarget], 
[LFtoUM], [customerQty], customerUM, [freightCost], 
[WRD], [lastChange], [projectedCost], 
[per], [pickup], [numbSource], [wholeUnits], 
[ob_Quotes_REN], [ob_Quotes_RID], [ob_Quotes_RMA]) 
    SELECT NEXT VALUE FOR BAS_IDGEN_SEQ, 1, getDate(),
    @SuggestedPrice, @tallyUM, @numbTarget,
    @LFperUM, @CustomerQty, @CustomerUM, @freightCost,
    @WRD, getDate(), @projectedCost,
    @per, @pickup, @numbSource, @wholeUnits,
    'Quotes', @QuoteID, 'om_QuoteCostLogs'
GO
