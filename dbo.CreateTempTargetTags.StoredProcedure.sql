USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateTempTargetTags]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateTempTargetTags]

@designDate     date = null,
@drillNumber    integer = null,
@orderLineID	integer = null

-- last change 12/05/22 --
as

set nocount on

delete from TempTargetTags
;


with w as (
select
ISNULL(N.west4East0,999) as westEast, row_Number() over (order by  N.rowNumber) as rowNo,
LEFT(ISNULL(N.handleLocationAlpha, I.CADHandle),2) as handle, L.tank, U.unit,
left(C.name,11) as name, LEFT(C.city,20) as city, left(O.PONumber,20) as PONumber, L.orderLineForDisplay




from ORDERLINES L
LEFT OUTER join
(select distinct ps_OrderLines_RID, west4East0, rowNumber, handleLocationAlpha
from NewHandleOrders) as N on N.ps_OrderLines_RID = L.ID

inner join ORDERS O on L.ob_Orders_RID = O.ID
inner join ITEMS I on L.ob_Items_RID = I.ID
inner join CUSTOMERS C on O.ob_Customers_RID = C.ID
inner join CADTRANSACTIONS T on T.ps_OrderLines_RID = L.ID
inner join UNITS U on T.ps_TargetUnit_RID = U.ID
inner join UNITLENGTHS UL on T.ps_UnitLengths_RID = UL.ID
inner join UNITS S on UL.ob_Units_RID = S.ID
inner join CADDRILLS CD on CD.ID = L.ps_CADDrills_RID
left outer join UnDigByMaxLen UML on UML.ob_Items_RID = I.ID and UML.maxlen = S.longLength

-- FOLLOWING DETERMINES IF SOURCE USED IN MORE THAN ONE TARGET
inner join (select S.ID, min(U.unit) as minTarget, max(U.unit) as maxTarget
    from CADTRANSACTIONS T
   inner join UNITS U on T.ps_TargetUnit_RID = U.ID
    inner join UNITLENGTHS UL on T.ps_UnitLengths_RID = UL.ID
    inner join UNITS S on UL.ob_Units_RID = S.ID
	inner join CADDrills CD on T.ps_CADDrills_RID = CD.ID
    where ((CD.designDate = @designDate and CD.drillNumber = @drillNumber)
	or T.ps_OrderLines_RID = @orderLineID)
    group by S.ID) as Z on Z.ID = S.ID

-- FOLLOWING GIVES SEQUENCE # FOR TARGETS FOR EACH HANDLING AREA
 inner join ( select ID, row_number() over (partition by handleArea order by ID) as newTargetNumber
	from (select distinct U.ID, U.handleArea
    from CADTRANSACTIONS T
    inner join UNITS U  on T.ps_TargetUnit_RID = U.ID
    inner join ORDERLINES L  on U.ps_OrderLines_RID = L.ID
	inner join CADDrills CD on T.ps_CADDrills_RID = CD.ID
    where ((CD.designDate = @designDate and CD.drillNumber = @drillNumber)
	or T.ps_OrderLines_RID = @orderLineID)
	and L.designStatus = 'Des'
   ) as x1
      )   as FEE on FEE.ID = U.ID

 inner join (select I.CADHandle, count(distinct ps_TargetUnit_RID) as numberOfTargets
    from CADTRANSACTIONS T inner join Units U on T.ps_TargetUnit_RID = U.ID
    inner join Items I on U.ob_Items_RID = I.ID
	inner join CADDrills CD on T.ps_CADDrills_RID = CD.ID
    where ((CD.designDate = @designDate and CD.drillNumber = @drillNumber)
	or T.ps_OrderLines_RID = @orderLineID)
    group by I.cadHandle) as TotTarg on TotTarg.CADHandle = I.CADHandle

    where ((CD.designDate = @designDate and CD.drillNumber = @drillNumber)
	or T.ps_OrderLines_RID = @orderLineID)
    and L.designStatus = 'Des' and C.ID <> 6456 -- SKIP NEWTECH
)

insert into TempTargetTags (ID, BASVERSION, BASTIMESTAMP,
	westEast, rowno, handle, tank, unit, name, city, PONumber, orderLineForDisplay)



select next value for myseq, 1, getdate(),
	westEast, row_number() over (order by westEast, X.rowno), handle,
	tank, unit, name, city, PONumber, orderLineForDisplay
	from (select
		westEast, min(rowno) as rowno, handle,
		tank, unit, name, city, PONumber, orderLineForDisplay
		from w group by westEast, handle, tank, unit, name, city, PONumber, OrderLineForDisplay) as X
GO
