USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadHandleTargetSourceUnits]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadHandleTargetSourceUnits]
@targetMobileID		integer = 11627929

-- last change 03/03/24

as

select U.unit, count(*) as numberLengths, sum(take) as totalTake, sum(took) as totalTook
from HandleTargetMobile HM inner join HandleTargetSources HS on HS.ob_HandleTargetMobile_RID = HM.ID
inner join HandleTargetLengths HL on HL.ob_HandleTargetMobile_RID = HM.ID and HL.ps_SourceUnit_RID = HS.ps_SourceUnit_RID
inner join Units U on HS.ps_SourceUnit_RID = U.ID
inner join Items I on U.ob_Items_RID = I.ID
where HM.ID = @targetMobileID 
group by U.unit
order by U.unit
GO
