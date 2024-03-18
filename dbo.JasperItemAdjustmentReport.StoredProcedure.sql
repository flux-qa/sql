USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[JasperItemAdjustmentReport]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[JasperItemAdjustmentReport]



@from   date = '05/01/2023',
@thru   date = '05/01/2023'

as



select 
case when SUA.ID IS NULL then 'Manual Adj' else 'Source Adj' end as type, I.oldcode as code, 
I.internalDescription as item, ULA.entered,
U.unit, ULA.length, ULA.originalQty as old, ULA.newQty as new, 
cast(case when I.UM <> 'PCS' then ULA.length / I.LFperUM else 1 end 
    * (ULA.newQty - ULA.originalQty) as integer) as deltaUM,
cast(case when I.UM <> 'PCS' then ULA.length / I.LFperUM else 1 end
    * (ULA.newQty - ULA.originalQty) * I.mktPrice / I.UMPer as integer) as deltaDollars,
R.LoginName as who
from UnitLengthsAdjustmentLog ULA inner join UnitLengths L on ULA.ps_UnitLengths_RID = L.ID
inner join Units U on L.ob_Units_RID = U.ID
inner join Items I on U.ob_Items_RID = I.ID
inner join RegularUser R on ULA.ps_RegularUser_RID = R.ID
left outer join SourceUnitAdjustmentLog SUA on SUA.ps_SourceUnitLength_RID = L.ID
    and abs(dateDiff(s, ULA.entered, SUA.entered)) < 2

where  cast(ULA.entered as date) between @from and @thru 
    and cast(U.dateReceived as date) < cast(ULA.entered as date)


union all


select 
 'Source Adj' as type, I.oldcode as code, I.internalDescription as item, SUA.entered,
U.unit, SUA.length, SUA.take as old, SUA.took as new, 
cast(case when I.UM <> 'PCS' then SUA.length / I.LFperUM else 1 end 
    * (SUA.take - SUA.took) as integer) as deltaUM,
cast(case when I.UM <> 'PCS' then SUA.length / I.LFperUM else 1 end
    * (SUA.take - SUA.took) * I.mktPrice / I.UMPer as integer) as deltaDollars,
R.LoginName as who
from SourceUnitAdjustmentLog SUA inner join UnitLengths L on SUA.ps_SourceUnitLength_RID = L.ID
inner join Units U on L.ob_Units_RID = U.ID
inner join Items I on U.ob_Items_RID = I.ID
inner join RegularUser R on SUA.ps_RegularUser_RID = R.ID
left outer join UnitLengthsAdjustmentLog ULA on ULA.ps_UnitLengths_RID = L.ID
and abs(dateDiff(s, ULA.entered, SUA.entered)) < 2

where  cast(SUA.entered as date) between @from and @thru
and ULA.ID IS NULL

order by I.oldcode, 3
GO
