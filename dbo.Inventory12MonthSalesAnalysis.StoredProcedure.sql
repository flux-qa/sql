USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[Inventory12MonthSalesAnalysis]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Inventory12MonthSalesAnalysis]
-- last change 05/30/23 -- skipped consignment POs
as


select  I.oldcode as code, I.internalDescription as item,
        cast((I.UMStock + ISNULL(totVPO,0) - I.consignmentUM) * I.avgCost / I.UMPer as integer) ourValue,
		--cast(L.dollarsShipped as integer) as dollarsShipped,
		case when I.UMStock + ISNULL(totVPO,0) - I.consignmentUM < 1 then 0 else
			cast (1.0 * L.totShipped / (I.UMStock + ISNULL(totVPO,0) - I.consignmentUM) as decimal(9,1)) end as turns,
		--cast(dollarsProfit as integer) as profit,
		case when dollarsShipped > 0 then cast(100.0 * dollarsProfit / dollarsShipped as decimal(8,1)) else 0 end as profitPct,
		I.UMStock + ISNULL(totVPO,0) - I.consignmentUM as ourStock,
        I.UMPocketWood as pocketwood, I.consignmentUM as consignment,
		L.totShipped





    from Items I left outer join
        (select ob_Items_RID, sum(UMShipped) as totShipped,
                sum (case when C.contractorFlag = 1 then 0 
					else UMShipped * ActualPrice / per end) as dollarsShipped,
				sum (case when C.contractorFlag = 1 then 0 
					else UMShipped * projectedCost / per end) as dollarsCost,
                sum (case when C.contractorFlag = 1 then 0 
					else UMShipped * (ActualPrice - projectedCost) / per end) as dollarsProfit
        from orderLines l inner join Orders O on L.ob_Orders_RID = O.ID 
        inner join Customers C on O.ob_Customers_RID = C.ID       
        where L.dateShipped > dateadd(yy, -1, getdate()) group by ob_Items_RID) as L on L.ob_Items_RID = I.ID
        
        left outer join (select PL.ob_Items_RID, sum(PL.quantityOrdered) as totVPO from PurchaseLines PL 
            inner join PurchaseOrders P on PL.ob_PurchaseOrders_RID = P.ID 
            where (PL.status = 'Open' and P.consignmentFlag <> 1 ) group by ob_Items_RID ) 
            as P on P.ob_Items_RID = I.ID


where  I.UMStock > 0 or L.totShipped > 0
order by I.oldcode
GO
