USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[TripToProposed]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[TripToProposed]
@tripNo integer

as

declare @tripNumber integer

select @tripNumber = tripNumber from TRIPCALENDAR where ID = @TripNo

select @tripNumber

-- Update the Unit Lengths 
update UNITLENGTHS set qtyOnHand = qtyShipped, qtyShipped = 0
from UNITLENGTHS UL inner join UNITS U on UL.ob_Units_RID = U.ID
--inner join ORDERUNITS OU on OU.ps_Units_RID = U.ID
inner join ORDERLINES L on U.ps_OrderLines_RID = L.ID
WHERE L.tripNumber = @TripNumber AND UL.qtyOnHand = 0 AND UL.qtyShipped > 0

-- UPDATE UNITS
update UNITS 
set UMStock = U.UMShipped, piecesStock = U.piecesShipped, UMShipped = 0, piecesShipped = 0,
 dateShipped = NULL
from UNITS U 
inner join ORDERLINES L on U.ps_OrderLines_RID = L.ID
WHERE L.tripNumber = @TripNumber

-- Increase the Stock 
Update ITEMS set UMStock = UMStock + Z.UMShipped from 
ITEMS I inner join (select L.ob_Items_RID as ID, sum(UMShipped) as UMShipped
    from ORDERLINES L 
    WHERE L.tripNumber = @TripNumber
    group by L.ob_Items_RID) as Z on Z.ID = I.ID


-- Update OrderLines - UMShipped and DateShipped
Update ORDERLINES set dateShipped = null, shipDateOrDesignStatus = designStatus, shippedFlag = 0,
UMShipped = 0
from ORDERLINES L  
WHERE L.tripNumber = @TripNumber

-- update Orders
Update ORDERS set dateShipped = null
from  ORDERS O inner join 
ORDERLINES L  ON L.ob_Orders_RID = O.ID
WHERE L.tripNumber = @TripNumber
GO
