USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ComputeOrderTallyTotalPiecesAndAvailable]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ComputeOrderTallyTotalPiecesAndAvailable]
as


update ORDERTALLY
set piecesStock = coalesce(Z.piecesStock,0)

from ORDERTALLY T inner join ORDERLINES L on T.ob_OrderLines_RID = L.ID
left outer join (select U.ob_Items_RID as itemID, L.length, sum(qtyOnHand) as piecesStock
    from UNITLENGTHS L inner join UNITS U on L.ob_Units_RID = U.ID 
    where qtyOnHand > 0
    group by U.ob_Items_RID, length) as Z on L.ob_Items_RID = Z.itemID and T.length = Z.length
where L.UMShipped = 0


update ORDERTALLY
set piecesAvailable = piecesStock - Z.totalTaken

from ORDERTALLY T inner join ORDERLINES L on T.ob_OrderLines_RID = L.ID
left outer join (select L.ob_Items_RID as itemID, T.length, sum(pieces) as totalTaken
    from ORDERTALLY T inner join ORDERLINES L on T.ob_OrderLines_RID = L.ID
    where L.UMShipped = 0
    group by L.ob_Items_RID, T.length) as Z on L.ob_Items_RID = Z.itemID and T.length = Z.length
where L.UMShipped = 0
GO
