USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateHandleTargetLengths]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateHandleTargetLengths]
-- last change 02/13/24


@designDate     date = '02/12/24',
@drillNumber    integer = 1

as



declare @CADDrillID     integer

select @CADDrillID = ID from CADDrills 
    where designDate = @designDate and drillNumber = @drillNumber


delete from HandleTargetLengths WHERE ps_CADDrills_RID = @CADDrillID


INSERT INTO [dbo].[HANDLETARGETLENGTHS]([ID], [BASVERSION], [BASTIMESTAMP], 
[ob_HandleTargetMobile_REN], [ob_HandleTargetMobile_RID], [ob_HandleTargetMobile_RMA],
ps_CADDrills_REN, ps_CADDrills_RID,
[ps_SourceUnit_REN], [ps_SourceUnit_RID], 
[unitNumber], [length], take, takeAll, took, tookAll, [balance], piecesNested) 



select next value for mySeq, 1, getDate(),
'HandleTargetMobile', M.ID, 'om_HandleTargetLengths',
'CADDrills', @CADDrillID,
'Units', U.ID, 
U.unit, L.length, T.take, T.takeAll, T.take, T.takeAll, 0, 0 
    FROM CADTransactions T inner join HandleTargetMobile M on 
    T.ps_TargetUnit_RID = M.ps_TargetUnit_RID
    inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
    inner join Units U on L.ob_Units_RID = U.ID
    where T.ps_CADDrills_RID = @CADDrillID


select next value for mySeq, 1, getDate(),
0, 0, 0, 'Waiting For Digs',
'Customers', CID,
'Units', ps_TargetUnit_RID,
'Items', ob_Items_RID,
'CADDrills', @CADDrillID,
'OrderLines', LID,
eastOrWest, handleLocation, rowNumber, tank

from (select distinct case when N.west4East0 = 0 then 'E' else 'W' end as eastOrWest,
    N.handleLocation, N.rowNumber, L.tank,
    C.ID as CID, T.ps_TargetUnit_RID, L.ob_Items_RID, L.ID as LID
        FROM CADTransactions T inner join OrderLines L on T.ps_OrderLines_RID = L.ID
        inner join Orders O on L.ob_Orders_RID = O.ID
        inner join Customers C on O.ob_Customers_RID = C.ID
        inner join NewHandleOrders N on N.ps_OrderLines_RID = T.ps_OrderLines_RID
        where T.ps_CADDrills_RID = @CADDrillID) as Z
GO
