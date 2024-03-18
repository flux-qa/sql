USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateUnitsPreferredLocationOnePO]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateUnitsPreferredLocationOnePO] 
@PONumber		integer 

as


Update Units set location = dbo.showUnitPreferredBay(U.unit)

from PurchaseOrders P inner join PurchaseLines L on L.ob_PurchaseOrders_RID = P.ID 
inner join Units U on U.ps_purchaseLines_RID = L.ID 
where P.PONumber = @PONumber
and U.location IS NULL
and dbo.showUnitPreferredBay(U.unit) is not null
GO
