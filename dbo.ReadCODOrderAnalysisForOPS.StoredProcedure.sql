USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadCODOrderAnalysisForOPS]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadCODOrderAnalysisForOPS] 

as

select row_Number() over (order by T.startTime, C.name, O.orderNumber) as ID, 
    1 as BASVERSION, getdate() as BASTIMESTAMP,
    RTRIM(LTRIM(left(dateName(dw, getdate()),3))) + ' ' + convert(char(11), T.startTime, 7) as tripDate, 
    T.startTime, C.name, O.orderNumber, L.lineNumber, 
    U.unit, Z.designDate, Z.drillNumber, U.location, L.designStatus, I.oldCode, I.internalDescription



    from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Items I on L.ob_Items_RID = I.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    inner join TripStopDetails TSD on TSD.ps_OrderLines_RID = L.ID
    inner join TripStops TS on TSD.ob_TripStops_RID = TS.ID
    inner join TripCalendar T on TS.ob_TripCalendar_RID = T.ID
    left outer join Units U on U.ps_OrderLines_RID = L.ID
    left outer join (select T.ps_OrderLines_RID, T.ps_TargetUnit_RID, max(D.designDate) as designDate, max(drillNumber) as drillNumber
        from CADTransactions T inner join CADDrills D on T.ps_CADDrills_RID = D.ID
        group by T.ps_OrderLines_RID, T.ps_TargetUnit_RID) as Z on Z.ps_OrderLines_RID = L.ID and Z.ps_TargetUnit_RID = U.ID
    
    
    where O.codFlag = 1 and L.UMShipped = 0
    order by T.startTime, C.name, O.orderNumber
GO
