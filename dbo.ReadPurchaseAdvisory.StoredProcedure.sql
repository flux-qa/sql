USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadPurchaseAdvisory]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadPurchaseAdvisory]

@dim1           float = 0,
@dim2           float = 0,
@itemSearch     varchar(100) = '%',
@itemSearch2    varchar(100) = '%',
@itemSearch3    varchar(100) = '%',
--@onlyStock      integer = 0,
--@onlyPocketWood integer = 0,
@selectedVendor integer = 0

AS

if (@ItemSearch <> '%')
    set @ItemSearch = '%' + LTRIM(RTRIM(@ItemSearch)) + '%'
if (@ItemSearch2 <> '%')
    set @ItemSearch2 = '%' + LTRIM(RTRIM(@ItemSearch2)) + '%'
if (@ItemSearch3 <> '%')
    set @ItemSearch3 = '%' + LTRIM(RTRIM(@ItemSearch3)) + '%'


SELECT P.ID, P.BASVERSION, P.BASTIMESTAMP, toOrder, lastPO, P.buyer, currentNumberOfCustomers, 
dailyUsage, avgUsage, oldAvgUsage, maxCurrentUsage, P.UMAvailable, P.leadTime, avgCurrentUsage,
 stockDays, UMUnshipped, maxLastUsage, P.pctTemplatable, deltaValueTemplatable, ps_Items_REN,
 ps_Items_RID, ps_Items_RMA, openToBuyGrowth, noLastUsage, oldGrowth, openToBuyGrowthFormatted, 
usage, P.UMPocketWood, P.LFperUM, stockDaysGrowth, numberOfCustomers, daysToOrder, 
stockDaysTemplatable, avgLastUsage, monthlyUsage, toOrderGrowth, oldNoUsage, pctTemplatableFormatted, 
P.UM, actualUsage, openToBuy, noCurrentUsage, P.item, P.UMStock, noUsage, daysOOS, P.oldCode, 
safetyStockInDays, oldUsage, P.LFperBME, idxAgressiveness, P.UMTemplatable, internalDescription, 
P.UMOpenPO, oldMaxUsage, maxUsage, currentUsage, lastPOQty, lastUsage, dim3, growth, dim2, 
momentum, dim1, projectedUsage, avgCost, oldNumberOfCustomers, toBuyFutureBuys, ruleUsed, 
pocketWoodValue, oldRuleUsed, lastNumberOfCustomers, UMPer, oldProjectedUsage, estReceived, toPurchase 
	FROM dbo.PurchaseAdvisory P 
--inner join Items I on P.ID = I.ID

 WHERE (@dim1 = 0 or @dim1 = dim1) AND
        (@dim2 = 0 or @dim2 = dim2) AND
        (@itemSearch = '%' or internalDescription like @ItemSearch) AND
        (@itemSearch2 = '%' or internalDescription like @ItemSearch2) AND
        (@itemSearch3 = '%' or internalDescription like @ItemSearch3) AND
        (@selectedVendor = 0 or ID in (select L.ob_Items_RID
            from PURCHASELINES L inner join PURCHASEORDERS P on L.ob_PurchaseOrders_RID = P.ID 
            where P.ob_Vendors_RID = @SelectedVendor))



Order by toOrderGrowth
GO
