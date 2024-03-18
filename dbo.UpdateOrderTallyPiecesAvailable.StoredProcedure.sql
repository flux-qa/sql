USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateOrderTallyPiecesAvailable]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateOrderTallyPiecesAvailable]
as

update OrderTally set piecesAvailable = Z.totalPcs - Y.allocated

    from OrderTally T inner join OrderLines L on T.ob_OrderLines_RID = L.ID
    -- GET TOTAL STOCK FROM UNIT LENGTHS
    inner join (select U.ob_items_RID, L.length, sum(qtyOnHand) as totalPcs
        from Units U inner join UnitLengths L on L.ob_Units_RID = U.ID
        where L.qtyOnHand > 0 and U.pocketWoodFlag = 0 group by ob_Items_RID, length) as Z
        on Z.ob_Items_RID = L.ob_Items_RID and Z.length = T.length
    -- GET TOTAL ALLOCATED FROM ORDER TALLY
    inner join (select L.ob_Items_RID, T.length, sum(T.pieces) as allocated from 
        OrderTally T inner join OrderLines L on T.ob_OrderLines_RID = L.ID
        where L.UMShipped = 0 and L.ps_PurchaseLines_RID is null group by L.ob_items_RID, T.length) as Y 
            on L.ob_Items_RID = Y.ob_items_RID and T.length = Y.length
            
            
    Where L.umShipped = 0 and T.piecesAvailable <> Z.totalpcs - Y.allocated
        and L.ps_PurchaseLines_RID is null
GO
