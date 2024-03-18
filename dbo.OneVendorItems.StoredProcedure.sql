USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[OneVendorItems]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OneVendorItems]
--
-- 12/23/15 
--

@Vendor integer

as 

    select ID, 
    item, dim1, dim2, dim3, internalDescription,  
    left(UM,3) as UM, UMPer, UMAvailable, 
    UMUnshipped, UMOpenPO, UMTemplatable, UMPocketWood, LFperUM,  LFperBME, 
    avgCost,  safetyStockInDays, idxAgressiveness, buyer, oldCode, estReceived, lastPO, 
    lastPOQty, leadTime, stockDays, openToBuy,  toOrder, openToBuyGrowth, toOrderGrowth,
    momentum, growth, 
    monthlyUsage, dailyUsage, usage, noUsage, maxUsage, avgUsage,
    currentUsage,  noCurrentUsage, maxCurrentUsage, avgCurrentUsage,
    lastUsage, noLastUsage, maxLastUsage, avgLastUsage, 
    ps_Items_REN, ps_Items_RID, null

    from PURCHASEADVISORY
    where ID in (
        select distinct ob_Items_RID from PURCHASELINES L 
        inner join PURCHASEORDERS P on L.ob_PurchaseOrders_RID = P.ID
        where P.ob_Vendors_RID = @Vendor)
GO
