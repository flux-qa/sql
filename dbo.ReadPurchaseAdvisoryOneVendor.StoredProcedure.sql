USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadPurchaseAdvisoryOneVendor]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadPurchaseAdvisoryOneVendor]

@vendorID integer,
@loginName varchar(20)

as

SELECT [ID], 1 as BASVERSION, getDate() as BASTIMESTAMP, [toOrder], [lastPO], [buyer], [dailyUsage], [avgUsage], 
[maxCurrentUsage], [UMAvailable], [leadTime], [avgCurrentUsage], [stockDays], [maxLastUsage], 
[ps_Items_REN], [ps_Items_RID], [ps_Items_RMA], [openToBuyGrowth], [noLastUsage], [usage], 
[UMPocketWood], [LFperUM], [avgLastUsage], [monthlyUsage], [UM], [noCurrentUsage], [openToBuy], 
[item], [noUsage], [safetyStockInDays], [oldCode], [LFperBME], [idxAgressiveness], [UMTemplatable], 
[internalDescription], [UMOpenPO], [currentUsage], [maxUsage], [lastPOQty], [dim3], [lastUsage], 
[dim2], [growth], [dim1], [momentum], [avgCost], [UMPer], [estReceived], [UMUnshipped], [UMStock], 
[deltaValueTemplatable], [pctTemplatable], [stockDaysTemplatable], [stockDaysGrowth], [projectedUsage], 
[daysToOrder], [ruleUsed], [numberOfCustomers], [pctTemplatableFormatted], [pocketWoodValue], 
[currentNumberOfCustomers], [lastNumberOfCustomers], [oldAvgUsage], [oldNoUsage], [oldUsage], 
[oldMaxUsage], [oldNumberOfCustomers], [oldProjectedUsage], [oldRuleUsed], [oldGrowth], 
[actualUsage], [toBuyFutureBuys], [daysOOS], [openToBuyGrowthFormatted], [toOrderGrowth], loginName, itemID 
	FROM [dbo].[PurchaseAdvisory]

where loginName = @loginName and itemID in (select L.ob_Items_RID
from PURCHASELINES L inner join PURCHASEORDERS P on L.ob_PurchaseOrders_RID = P.ID
where P.ob_Vendors_RID = @vendorID)

order by toOrderGrowth
GO
