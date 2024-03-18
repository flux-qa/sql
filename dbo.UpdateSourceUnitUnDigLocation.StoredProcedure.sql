USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateSourceUnitUnDigLocation]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateSourceUnitUnDigLocation]
@Unit integer

as



declare @orderLineID    integer


SET NOCOUNT ON

select @orderLineID = ps_OrderLines_RID
    from Units where ID = @Unit


insert into SourceUnitUndigLog (unit) select @unit

INSERT INTO [dbo].[BayChangeLogAudit]([ID], [BASVERSION], [BASTIMESTAMP], 
[dateEntered], [ps_RegularUser_REN], [ps_RegularUser_RID], 
[currentBay], [newBay], [unitNumber], 
[ps_Units_REN], [ps_Units_RID]) 


select next value for bas_IDGEN_SEQ, 1, getdate(),
getdate(), 'RegularUser', 3, currentBay, newBay, unitNumber, 'Units', UID
from 
(select distinct U.location as currentBay,
case when UML.location is not null and UML.location <> '' then UML.location 
    when I.CADUnDigToShort is not null and I.CADUnDigToShort <> '' and I.CADUndigToShort is not null and longLen < 10 then I.CADUnDigToShort
    when I.CADUnDigToLong is not null and I.CADUnDigToLong <> '' and I.CADUndigTOLong is not null and longLen > 16 then I.CADUndigToLong
    else I.CADUnDigTo end as newBay, 
 U.unit as unitNumber,
 U.ID as UID 

from UNITS U inner join ITEMS I on U.ob_Items_RID = I.ID
inner join UNITLENGTHS L on L.ob_Units_RID = U.ID
inner join CADTRANSACTIONS C on C.ps_UnitLengths_RID = L.ID
inner join (select ob_Units_RID as unitID, min(length) as shortLen, max(length) as longLen
    from UnitLengths where qtyOnHand > 0 group by ob_Units_RID) as Z on Z.unitID = U.ID
    left outer join UndigByMaxLen UML on UML.ob_Items_RID = I.ID and UML.maxlen = Z.longLen    

where C.ps_TargetUnit_RID = @unit and I.CADUnDigTo <> '' and I.CADUnDigTo is not null
and left(i.oldcode,1) <> '8'
AND U.ID not in (select U.ID 
    from CADTransactions C inner join UnitLengths L on C.ps_UnitLengths_RID = L.ID
    inner join Units U on L.ob_Units_RID = U.ID
    inner join OrderLines O on C.ps_OrderLines_RID = O.ID
    inner join CADDrills CD on C.ps_CADDrills_RID = CD.ID
    where O.designStatus = 'Des' and CD.designDate <= getdate() 
    and O.ID <> @orderLineID
    and C.ps_TargetUnit_RID <> @unit)) as Y



update UNITS
set location = 
case when UML.location is not null and UML.location <> '' then UML.location  
    when I.CADUnDigToShort is not null and I.CADUnDigToShort <> '' and I.CADUndigToShort is not null and longLen < 10 then I.CADUnDigToShort
    when I.CADUnDigToLong is not null and I.CADUnDigToLong <> '' and I.CADUndigTOLong is not null and longLen > 16 then I.CADUndigToLong
else I.CADUnDigTo end,
unitType = ''

from UNITS U inner join ITEMS I on U.ob_Items_RID = I.ID
inner join UNITLENGTHS L on L.ob_Units_RID = U.ID
inner join CADTRANSACTIONS C on C.ps_UnitLengths_RID = L.ID
inner join (select ob_Units_RID as unitID, min(length) as shortLen, max(length) as longLen
    from UnitLengths where qtyOnHand > 0 group by ob_Units_RID) as Z on Z.unitID = U.ID
left outer join UndigByMaxLen UML on UML.ob_Items_RID = I.ID and UML.maxlen = Z.longLen    

where C.ps_TargetUnit_RID = @unit and I.CADUnDigTo <> '' and I.CADUnDigTo is not null
and left(i.oldcode,1) <> '8'
AND U.ID not in (select U.ID 
    from CADTransactions C inner join UnitLengths L on C.ps_UnitLengths_RID = L.ID
    inner join Units U on L.ob_Units_RID = U.ID
    inner join OrderLines O on C.ps_OrderLines_RID = O.ID
    inner join CADDrills CD on C.ps_CADDrills_RID = CD.ID
    where O.designStatus = 'Des' and CD.designDate <= getdate() 
    and O.ID <> @orderLineID
    and C.ps_TargetUnit_RID <> @unit)
GO
