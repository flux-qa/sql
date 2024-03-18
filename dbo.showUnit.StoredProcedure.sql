USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[showUnit]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[showUnit] 

@unit integer

as

select U.unit, U.dateEntered as entered, U.dateShipped as shipped, 
U.piecesStock as stockPcs, U.piecesShipped as shippedPcs,
L.length, L.qtyOnHand as pcs, L.qtyShipped as shipped

from UnitLengths L inner join Units U on L.ob_Units_RID = U.id
where U.unit = @unit
order by L.length
GO
