USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateUnitsShippedFromUnitLengths]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateUnitsShippedFromUnitLengths]  

as

update units set UMShipped = 0, LFShipped = 0, piecesShipped = 0
where id in (select ob_units_RID from unitLengths group by ob_units_RID
 having sum(qtyShipped) = 0)
and UMShipped > 0 


Update Units
set  piecesShipped = coalesce(qtyShipped,0),
     LFShipped = coalesce(Z.LFShipped,0),
     UMShipped = ROUND(coalesce(Z.LFShipped,0) / I.LFperUM,0)
    
from Units U inner join Items I on U.ob_Items_RID = I.ID
    inner join (select ob_Units_RID as unitID, 
    sum(qtyShipped) as qtyShipped,
    sum(length * qtyShipped) as LFShipped
    from unitLengths WHERE qtyShipped > 0 group by ob_Units_RID) as Z on U.ID = Z.unitID
    
-- ALSO UPDATE THE ORDER LINES    
Update OrderLines set UMShipped = ROUND(coalesce(Z.LFShipped,0) / I.LFperUM,0)
    from OrderLines L
    inner join Items I on L.ob_Items_RID = I.ID
    inner join (select ps_OrderLines_RID, 
        sum(qtyShipped) as qtyShipped,
        sum(length * qtyShipped) as LFShipped
        from unitLengths L inner join Units U on L.ob_Units_RID = U.ID
        WHERE qtyShipped > 0  group by ps_OrderLines_RID) as Z on L.ID = Z.ps_OrderLines_RID
        WHERE L.wrd = 'W'
GO
