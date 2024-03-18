USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateOrderTotalsByOrderLine]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateOrderTotalsByOrderLine]

@fromDate       date,
@thruDate       date,
@dateType       varchar(8) = 'Entered'


as

delete from OrderTotalsByOrderLine

INSERT INTO OrderTotalsByOrderLine (ID, BASVERSION, BASTIMESTAMP,
    orderNumber, lineNumber, name, dateEntered, code, item, 
    UMOrdered, UM, qtyFormatted, price, priceFormatted, avgCost,
    freightCost, handlingCost, materialCost, projectedCost, profitPct, profitDollars,
    shipto, fieldRep, outsideRep, keyboarder, tallydeltaPct, designComments, orderLineForDisplay, customerID )

select row_number() over (order by O.orderNumber) as ID, 1 as BASVERSION, getdate() as BASTIMESTAMP,
    O.orderNumber, L.lineNumber, C2.name, O.dateEntered, I.oldCode as code, I.internalDescription as item,
    L.UMOrdered, I.UM, L.qtyFormatted, L.actualPrice as price, L.priceFormatted, L.avgCost, 
    L.freightCost, L.handlingCost, L.materialCost, L.projectedCost,
    round(case when L.actualPrice > 0 then 100.0 * (L.actualPrice - (L.materialCost + isNull(M.freightCost,0))) 
        / L.actualPrice else 0 end,1) as profitPct,
    round(case when C.contractorFlag = 1 then 0 else L.UMOrdered * (L.actualPrice - L.projectedCost) / L.per end,0) as profitDollars,
    c.name, left(c.fieldRep,2), left(C.outsideFieldRep,2), R.loginName, 
    case when L.tallyDeltaPct = 0 then '' else RTRIM(LTRIM(cast(L.tallyDeltaPct as char(5)))) end as tallyDeltaPct, L.designComments,
    L.orderLineForDisplay, C.ID


    from orderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    inner join RegularUser R on O.ps_UserID_RID = R.ID
    inner join Items I on L.ob_Items_RID = I.ID
    inner join Customers C on O.originalShipTo_RID = C.ID
    inner join Customers C2 on O.ob_Customers_RID = C2.ID
    left outer join OrderLines M on L.ps_LinkToContractorOrderLine_RID = M.ID
    where (@dateType = 'Entered' AND cast(O.dateEntered as date) between @fromDate and @thruDate)
           OR (@dateType = 'Shipped' AND cast(L.dateShipped as date) between @fromDate and @thruDate)
GO
