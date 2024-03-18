USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateUnitAdjustmentsForDateRange]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateUnitAdjustmentsForDateRange]
@fromDate   date = '07/01/2022',
@thruDate   date = '08/01/2022'

as
delete from UnitAdjustmentsForDateRange

set @thruDate = DateAdd(DD,1, @thruDate)
;

with w as (select 'Adj.' as type, row_number() over (partition by U.ID, L.ID order by U.ID, L.ID, ULA.entered) as rowno, 
I.oldCode as code, I.internalDescription as item, I.avgCost as avgCost, I.UMPer,
ULA.entered, R.LoginName as who, U.unit, cast(U.dateReceived as date) as recvd,
 RTRIM(cast(L.length as varchar(3))) + '''' as length, L.length as origLength, ULA.originalQty as origQty, ULA.newQty, I.LFperUM

    from UnitLengthsAdjustmentLog ULA inner join UnitLengths L on ULA.ps_UnitLengths_RID = L.ID
    inner join Units U on L.ob_Units_RID = U.ID
    inner join Items I on U.ob_Items_RID = I.ID
    inner join RegularUser R on ULA.ps_regularUser_RID = R.ID
    left outer join PhysicalInventoryLog P on P.unitNumber = U.Unit
    where DATEADD(dd, -2, ULA.entered) > U.dateEntered
    and cast(ULA.entered as date) > cast(U.dateReceived as date)
    and P.ID is null
    )
    
insert into UnitAdjustmentsForDateRange(ID, BASVERSION, BASTIMESTAMP,
    type, rowno, code, item, entered, who, unit, recvd, len, origQty, newQty, plusValue, minusValue)    
    
select next value for mySeq, 1, getDate(),

    type, rowno, code, item, entered, who, unit, recvd, length, origQty, newQty,
    case when newQty > origQty then round((newQty - origQty) * origLength / W.LFperUM * avgCost / UMper,0) else 0 end as plusValue,
    case when origQty > newQty then round((origQty - newQty) * origLength / W.LFperUM * avgCost / UMper,0) else 0 end as minusValue
    from W where entered > @fromDate and entered < @thruDate and (rowno > 1 or origQty <> 0)
;

    with x as (select 'S.U.A.' as type, 2 as rowno, I.oldCode as code, I.internalDescription as item, SUA.entered, R.LoginName who, U.unit, U.dateReceived as recvd, SUA.length, take, took,
        case when take > took then round((take - took) / I.LFperUM * avgCost / UMper,0) else 0 end as plusValue,
    case when take <= took then round((took - take) / I.LFperUM * avgCost / UMper,0) else 0 end as minusValue

    from SourceUnitAdjustmentLog  SUA inner join UnitLengths L on SUA.ps_SourceUnitLength_RID = L.ID
    inner join Units U on L.ob_Units_RID = U.ID
    inner join Items I on U.ob_Items_RID = I.ID
    inner join RegularUser R on SUA.ps_RegularUser_RID = R.ID
    where SUA.entered > @fromDate and SUA.entered < @thruDate  ) 
    
    
    
insert into UnitAdjustmentsForDateRange(ID, BASVERSION, BASTIMESTAMP,
    type, rowno, code, item, entered, who, unit, recvd, len, origQty, newQty, plusValue, minusValue)    
    
    select next value for mySeq, 1, getDate(),
    type, rowno, code, item, entered, who, unit, recvd, length, take, took, plusValue, minusValue from X
GO
