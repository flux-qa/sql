USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ItemSearchOneCustomer]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ItemSearchOneCustomer]
@custno integer = 0,
@searchField varchar(200) = '',
@searchField2 varchar(200) = '',
@searchField3 varchar(200) = '',
@Dim1   float = 0,
@Dim2   float = 0,
@StockOnly integer = 0,

@product varchar(30) = 'ALL',
@pattern varchar(20) = 'ALL',
@oldCode varchar(8) = '%'

as

set @oldCode = RTRIM(LTRIM(@oldCode)) + '%'

if @SearchField <> ''
set @searchField = '%' + LTRIM(RTRIM(@searchField)) + '%'
if @SearchField2 <> ''
set @searchField2 = '%' + LTRIM(RTRIM(@searchField2)) + '%'
if @SearchField3 <> ''
set @searchField3 = '%' + LTRIM(RTRIM(@searchField3)) + '%'

select ID, BASVERSION, BASTIMESTAMP, 0 as item,
oldCode, dim1, dim2, dim3, internalDescription, internalDescription as customerDescription,
UMStock, UMAvailable, UMOpenPO, UM, LFperUM, avgCost, approxValue,
Y.lastOrder, case when Y.lastOrder is null then 1 else 0 end as sortOrder,
case when UMAvailable > 0 or UMOpenPO > 0 then 0 else 1 end as sortOrder2,
 LFPer, LFOpenPO, grossMargin, ps_CostAddOn_REN, ps_CostAddOn_RID, ps_CostAddOn_RMA, 
 ob_UMCode_REN, ob_UMCode_RID, ob_UMCode_RMA, qtyForNewPO,  LFDamaged, pcsBundle, 
 UMAvailableString, lastCost, CADUnDigTo, templateTotalSuggestedPct, product, 
 pctTemplatable, daysNegotiation, CADHandle, daysTransit, deltaValueTemplatable, LFUnShipped, 
 UMPocketWood, LFPocketWood,  mktCost, leadTime, daysToOrder, safetyStockInDays, 
 overshipPct, LFperBME, CADSingleVendor, UMPer, UMOpenPOString, LFTemplatable, 
UMUnShipped, compl2Move, MEOQ, LFStock, maxPctOverTemplate, CADUnDigToShort, 
 oldCode, CADUndigToLong, dimString, CADWHoleUnitsOnly, buyer, CADWidthPieces, 
 standardUnitSize, daysToSunsetQuote, idxAgressiveness, 
 CADLargest, UMTemplatable, minimumUnitPrice,   UMPerString, 
 oldPocketWoodCode, minutesSinceMidnight, ps_InventoryRebates_REN, ps_InventoryRebates_RID, 
 ps_InventoryRebates_RMA, ps_Patterns_REN, ps_Patterns_RID, ps_Patterns_RMA, 
 oldPatternCode, whichCostToUse, shoppingBasket, noLensPerSourceUnit, fragile, wholeUnitDifficultyFactor, 
 mktPrice, sourceUnitDifficultyFactor, targetUnitDifficultyFactor, squareUnit, targetUnitCost, 
 WUSell, defaultNoTargetsForQuote, defaultNoSourcesForQuote, CADMaxHeightPcs, LFperWeight, oldProduct,
 LFperCube,originalLFperUM, serviceItem, class, cellarprice, productcode, patterncode,defectiveFlag,
 UMDamaged, minUnitCostForReport, maxUnitCostForReport, noUnitsForReport, UMforReports,
 LFperPcs, QuoteInPieces, approxValueString, templateCostCode, CADMaxUnitSize, UMDirectPO,
 dateOverAllocated, storage, noCustomTallys, consignmentUM, consignmentCustomer, consignmentVendor, consignmentBillTo,
 consignmentAvgCost, consignmentLastCost,
 preferredBayStart, preferredBayEnd, doNotUnPocketwoodNonIntactUnits, eastOrWest


from ITEMS I left outer join
 --CustomersItemsLastOrder Y on Y.ob_Customers_RID = @custno and I.ID = Y.item
    
    (
    select L.ob_Items_RID as item,  Format(customerQty, '#,###') + ' ' +
    customerUM + ' @ ' + case when per = 1 then Format(actualPrice, '#,##0.00') else
    Format(actualPrice, '#,###') end + '/' + perString +
    ' on ' + format (dateEntered, 'd') as lastOrder, dateEntered as lastOrderDate
    from ORDERLINES L inner join ORDERS O on L.ob_Orders_RID = O.ID
    inner join CustomerItemsLastOrderID CI on CI.custno = @custno and CI.item = L.ob_Items_RID
    where O.ID = CI.maxID
    /*
    (select ob_Items_RID as item, max(O.ID) as maxID
        from ORDERLINES L inner join ORDERS O on L.ob_Orders_RID = O.ID
        where O.ob_Customers_RID = @Custno
        group by L.ob_Items_RID)
    as z on O.ID = Z.maxID) 
    */
    )as Y on  I.ID = Y.item

where (UMAvailable > 0 OR @StockOnly = 0)
AND (@searchfield = '' or I.internalDescription like @searchField)
AND (@searchfield2 = '' or I.internalDescription like @searchField2)
AND (@searchfield3 = '' or I.internalDescription like @searchField3)
AND (@Dim1 = 0 OR I.dim1 = @Dim1)
AND (@Dim2 = 0 OR I.dim2 = @Dim2)

    AND (@product = 'ALL' OR 
        (@product = 'White Soft Woods' AND I.oldProduct = '0') OR
       (@product = 'Non White Soft Woods' AND I.oldProduct = '1') OR
       (@product = 'HardWoods' AND I.oldProduct = 'H'))      
       
  AND (@pattern = 'ALL' OR 
        (@pattern = '4 Side' AND left(I.oldPatternCode,1) = '0') OR
       (@pattern = 'Pure Vee Joint' AND left(I.oldPatternCode,1) = '1') OR
       (@pattern = 'Other T & G' AND left(I.oldPatternCode,1) = '2') OR       
       (@pattern = 'Lap Joinder' AND left(I.oldPatternCode,1) = '3') OR
       (@pattern = 'Bevel' AND left(I.oldPatternCode,1) = '4'))   
           
  AND (@oldCode = '%' OR I.OldCode like @OldCode)         

order by sortOrder, sortOrder2, Y.lastOrderDate desc, I.dim1, I.dim2, I.internalDescription
GO
