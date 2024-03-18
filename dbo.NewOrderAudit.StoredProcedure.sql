USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[NewOrderAudit]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[NewOrderAudit]

AS

-- SEE IF ANY ORDER LINES HAVE THE WRONG ITEM CODE
IF EXISTS (select L.orderNumber, L.BASTIMESTAMP, L.ob_Items_RID, Q.ob_Items_RID
    from OrderLines L inner join Quotes Q on Q.ps_OrderLines_RID = L.ID
    where L.ob_Items_RID <> Q.ob_Items_RID) BEGIN
    
        Update OrderLines set ob_Items_RID = Q.ob_Items_RID, 
        itemOrSeagullDescription = ISNULL(Q.replaceDescription, I.internalDescription)   
        from OrderLines L inner join Quotes Q on Q.ps_OrderLines_RID = L.ID
        inner join Items I on Q.ob_Items_RID = I.ID
        where L.ob_Items_RID <> Q.ob_Items_RID
         
        EXEC UpdateUnitsFromUnitLengths
        END

/*
-- MAKE SURE CONTRACTOR ORDERS ARE LINKED TO CORRECT ITEM         
update OrderLines set ps_LinkToContractorOrderLine_RID = Q.ps_LinkToContractorOrderLine_RID
from OrderLines L inner join Quotes Q on Q.ps_OrderLines_RID = L.ID
where L.ps_LinkToContractorOrderLine_RID is not null and
Q.ps_LinkToContractorOrderLine_RID <> L.ps_LinkToContractorOrderLine_RID
*/
GO
