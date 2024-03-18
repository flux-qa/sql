USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadItemAdjustmentLog]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadItemAdjustmentLog]
-- LAST CHANGE 05/21/23 -- REMOVED SOURCE UNIT FROM REPORT
-- 11/06/23 -- Switched SUA Take - Took


@item   varchar(5) = 'NTH2',
@from   date = '03/01/2022',
@thru   date = '04/05/2022'



As

set @thru = dateadd(dd,1, @thru)


delete from ITEMADJUSTMENTLOG

Insert INTO ItemAdjustmentLog (ID, BASVERSION, BASTIMESTAMP,
type, code, entered, unit, length, old, new, deltaUM, who)

select next value for mySeq as ID, 1 as BASVERSION, getdate() as BASTIMESTAMP,
case when SUA.ID IS NULL then 'Manual Adj' else 'Source Adj' end as type, I.oldcode as code, ULA.entered,
U.unit, ULA.length, ULA.originalQty as old, ULA.newQty as new, 
case when I.UM <> 'PCS' then ULA.length / I.LFperUM else 1 end * (ULA.newQty - ULA.originalQty) as deltaUM,R.LoginName as who
from UnitLengthsAdjustmentLog ULA inner join UnitLengths L on ULA.ps_UnitLengths_RID = L.ID
inner join Units U on L.ob_Units_RID = U.ID
inner join Items I on U.ob_Items_RID = I.ID
inner join RegularUser R on ULA.ps_RegularUser_RID = R.ID
left outer join SourceUnitAdjustmentLog SUA on SUA.ps_SourceUnitLength_RID = L.ID
    and abs(dateDiff(s, ULA.entered, SUA.entered)) < 2

where I.oldcode like @item + '%' and ULA.entered between @from and @thru



Insert INTO ItemAdjustmentLog (ID, BASVERSION, BASTIMESTAMP,
type, code, entered, unit, length, old, new, deltaUM, who)

select next value for mySeq as ID, 1 as BASVERSION, getdate() as BASTIMESTAMP,
 'Source Adj' as type, I.oldcode as code, SUA.entered,
U.unit, SUA.length, SUA.take as old, SUA.took as new, 
case when I.UM <> 'PCS' then SUA.length / I.LFperUM else 1 end * (SUA.took - SUA.take) as deltaUM,R.LoginName as who
from SourceUnitAdjustmentLog SUA inner join UnitLengths L on SUA.ps_SourceUnitLength_RID = L.ID
inner join Units U on L.ob_Units_RID = U.ID
inner join Items I on U.ob_Items_RID = I.ID
inner join RegularUser R on SUA.ps_RegularUser_RID = R.ID
left outer join UnitLengthsAdjustmentLog ULA on ULA.ps_UnitLengths_RID = L.ID
and abs(dateDiff(s, ULA.entered, SUA.entered)) < 2

where I.oldcode like @item + '%' and SUA.entered between @from and @thru
and SUA.take <> SUA.took
and ULA.ID IS NULL
GO
