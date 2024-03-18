USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadHandleTargetLengthsOneTarget]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadHandleTargetLengthsOneTarget]
@targetMobileID		integer,
@unitNumber			integer = null

-- last change 03/03/24

as


select L.ID as orderLineID, L.orderLineForDisplay as orderNo, 
TU.ID as targetID, TU.unit as targetUnit, U.ID as sourceID, U.unit as sourceUnit, HM.ps_CADDrills_RID as drillID,
HL.ID as handleTargetLengthID,
C.name, I.oldcode as code, I.internalDescription as item,
L.UMOrdered, HL.length, HL.take, HL.took, HL.takeAll, HL.tookAll, HL.piecesNested
from HandleTargetMobile HM inner join HandleTargetSources HS on HS.ob_HandleTargetMobile_RID = HM.ID
inner join HandleTargetLengths HL on HL.ob_HandleTargetMobile_RID = HM.ID and HL.ps_SourceUnit_RID = HS.ps_SourceUnit_RID
inner join Customers C on HM.ps_Customer_RID = C.ID
inner join OrderLines L on HM.ps_OrderLines_RID = L.ID
inner join Units U on HS.ps_SourceUnit_RID = U.ID
inner join Units TU on HM.ps_TargetUnit_RID = TU.ID
inner join Items I on U.ob_Items_RID = I.ID
where HM.ID = @targetMobileID and (@unitNumber is null OR @unitNumber = 0 or @unitNumber = U.unit)
order by U.unit, HL.length
GO
