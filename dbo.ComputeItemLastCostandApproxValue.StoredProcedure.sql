USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ComputeItemLastCostandApproxValue]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ComputeItemLastCostandApproxValue]
as

-- 1st Update the Last Cost

Update Items set lastCost = AdjustedCost
    from PurchaseLines L inner join PurchaseOrders P on L.ob_purchaseOrders_RID = P.ID
    inner join Items I on L.ob_Items_RID = I.ID
    inner join ( select I.oldCode, max(P.PONumber) as lastPO
        from PurchaseLines L inner join PurchaseOrders P on L.ob_purchaseOrders_RID = P.ID
        inner join Items I on L.ob_Items_RID = I.ID
        where P.ps_Customers_RID is null AND (P.status = 'Open' or P.status = 'Ordered' or P.status = 'Complete')
        group by I.oldCode) as Z on I.oldCode = Z.oldCode and P.PONumber = Z.lastPO


-- Next Compute the Approx Value
Update Items set approxValue = Z.calcValue
--select I.oldCode, I.whichCostToUse, I.lastCost, I.avgCost, I.mktCost,
--I.approxValue, Z.calcValue, round(I.approxValue - Z.calcValue,2) as delta
    from items I inner join 
    (
    select ID, case when mktPrice > 0 then mktprice 
    else
        round(
        --when whichCostToUse = 'Highest' and avgcost >= lastCost and avgCost >= mktCost then avgCost
        --when whichCostToUse = 'Highest' and lastCost >= avgCost and lastCost >= mktCost then lastCost
        --when whichCostToUse = 'Highest' then mktCost
        case when whichCostToUse = 'Average' or whichCostToUse is null then avgcost
        when whichCostToUse = 'Last' then lastCost
        when whichCostToUse = 'Market' then mktCost
        else
            case when avgCost > 0 and avgCost >= lastCost and avgCost >=mktCost then avgcost
            when lastCost > 0 and lastCost >= mktcost then lastcost
            else mktCost end
        end
         / (1.0 - .01 * grossMargin), case when umper = 1 then 2 else 0 end) end as calcValue
    
        from items 
        --where mktprice > 0 or grossMargin > 0
    ) as Z on I.ID = Z.ID
    
    
-- 3rd Update the ApproxValue String
Update Items set approxValueString = 
    case when UMPer = 1 then Format(ApproxValue, '###,##0.00') 
    else format(ApproxValue, '###,##0')  end
GO
