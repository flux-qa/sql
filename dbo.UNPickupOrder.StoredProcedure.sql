USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UNPickupOrder]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UNPickupOrder]

@orderNumber integer 

as

-- 1st UNSHIP THE UNITS
update UnitLengths set qtyOnHand = qtyShipped, qtyshipped = 0
from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
inner join OrderLines OL on U.ps_OrderLines_RID = OL.ID
where OL.orderNumber = @orderNumber

-- 2nd UNSHIP THE ORDER LINES
Update OrderLines set UMShipped = 0, dateShipped = null
where orderNumber = @orderNumber

-- 3rd UNSHIP AND UNPICKUP THE ORDER
Update Orders set dateShipped = null, dateInvoiced = null,
    PODSigned = 0

where orderNumber = @orderNumber

exec UpdateUnitsFromUnitLengths
GO
