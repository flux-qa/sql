USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateHandleTargetMobile]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateHandleTargetMobile]

-- last change 02/13/24

@designDate     date = '02/12/24',
@drillNumber    integer = 1

-- last change 02/15/24

as

declare @CADDrillID     integer

select @CADDrillID = ID from CADDrills 
    where designDate = @designDate and drillNumber = @drillNumber


delete from HandleTargetMobile WHERE ps_CADDrills_RID = @CADDrillID


INSERT INTO [dbo].[HANDLETARGETMOBILE]([ID], [BASVERSION], [BASTIMESTAMP], 
[piecesHandled], [UMHandled], [LFHandled], [status], 
[ps_Customer_REN], [ps_Customer_RID],  
[ps_TargetUnit_REN], [ps_TargetUnit_RID], 
[ps_Items_REN], [ps_Items_RID],  
[ps_CADDrills_REN], [ps_CADDrills_RID],
[ps_OrderLines_REN], [ps_OrderLines_RID],
eastOrWest, handlingArea, rowNumber, tank) 


select next value for mySeq, 1, getDate(),
0, 0, 0, 'Waiting For Digs',
'Customers', CID,
'Units', ps_TargetUnit_RID,
'Items', ob_Items_RID,
'CADDrills', @CADDrillID,
'OrderLines', LID,
eastOrWest, case when handleLocation = '0' then 'E' when handleLocation = '9' then 'W' else handleLocation end as handleLocation, rowNumber, tank

from (select distinct case when N.west4East0 = 0 then 'E' else 'W' end as eastOrWest,
    N.handleLocation, N.rowNumber, L.tank,
    C.ID as CID, T.ps_TargetUnit_RID, L.ob_Items_RID, L.ID as LID
        FROM CADTransactions T inner join OrderLines L on T.ps_OrderLines_RID = L.ID
        inner join Orders O on L.ob_Orders_RID = O.ID
        inner join Customers C on O.ob_Customers_RID = C.ID
        inner join NewHandleOrders N on N.ps_OrderLines_RID = T.ps_OrderLines_RID
        where T.ps_CADDrills_RID = @CADDrillID) as Z
GO
