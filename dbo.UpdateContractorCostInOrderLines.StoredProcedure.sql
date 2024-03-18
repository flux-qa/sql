USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateContractorCostInOrderLines]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create Procedure [dbo].[UpdateContractorCostInOrderLines]

@orderID integer 

as

update OrderLines set contractorCostPerUM = ISNULL(contractorCostAddOn,0)
from OrderLines L inner join ( 
select L.ID, SUM(case when SC.priceMode = 'Flat' then  ROUND(1.0 * ISNULL(SC.cost,0) / L.customerQty * L.per,0) else ISNULL(SC.cost,0) end) as contractorCostAddOn
    from OrderLineServiceCharges SC inner join OrderLines L on SC.ob_OrderLines_RID = L.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
    where O.orderNumber = @orderID and L.customerQty > 0
    group by L.ID) as Z on L.ID = Z.ID
GO
