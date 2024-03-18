USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateLinkInContractorOrder]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateLinkInContractorOrder]

@newOrderNumber     integer,
@contractorOrder    integer

as


update OrderLines set ps_LinkToContractorOrderLine_REN = 'OrderLines',
ps_LinkToContractorOrderLine_RID = @newOrderNumber, contractorFlag = 1
    where ID = @contractorOrder
    
/*    
-- FIX WHERE LINKED TO WRONG QUOTE LINE
update OrderLines set ps_LinkToContractorOrderLine_RID = customerOrderID
from OrderLines L inner join (

select  L2.ID as contractorOrderID, L.ID as customerOrderID

    from OrderLines L inner join Quotes Q on Q.ps_OrderLines_RID = L.ID
    inner join OrderLines L2 on Q.ps_LinkToContractorOrderLine_RID = L2.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    
    where Q.ps_LinkToContractorOrderLine_RID is not NULL 
    and L.id <> L2.ps_LinkToContractorOrderLine_RID
    ) as Z on Z.contractorOrderID = L.ID
    
WHERE L.ob_Items_RID < 10000 OR  L.ob_Items_RID > 10010
-- FLAG CONTRACTOR ORDERS THAT ARE LINKED TO SALES ORDERS
*/
    
-- CLEAR LINKS TO FREIGHT / MISC
update OrderLines set ps_LinkToContractorOrderLine_RID = null
where ps_LinkToContractorOrderLine_RID > 0 and ob_Items_RID between 10000 and 10010
GO
