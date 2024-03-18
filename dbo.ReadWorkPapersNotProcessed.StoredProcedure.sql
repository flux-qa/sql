USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadWorkPapersNotProcessed]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadWorkPapersNotProcessed]
as

delete from WorkpapersNotProcessed


INSERT INTO [dbo].[WorkpapersNotProcessed]([ID], [BASVERSION], [BASTIMESTAMP], 
[tripDate], [tripNumber], [name], city, orderNo, code, item, drillNumber, targetUnit, codFlag) 


select row_number() over (order by L.ID) as ID, 1 as BASVERSION, getdate() as BASTIMESTAMP,
convert(varchar(10), T.startTime,1) as tripDate, T.tripNumber, 
    C.name, C.city, 
    rtrim(cast(O.orderNumber as char(10))) + '-' + cast(L.lineNumber as char(2)) as orderNo,
    case when U.location is null or U.location = '' then I.CADHandle else U.location end  as code,
    I.internalDescription as item, coalesce(y.drillNumber, Z.drillNumber,0) as drillNumber, 
    case when U.Unit is not null then U.Unit else Z.unit end as targetUnit, O.codFlag

    from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    left outer join Units U on U.ps_orderLines_RID = L.ID

    inner join Items I on L.ob_Items_RID = I.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    inner join TripStopDetails TSD on TSD.ps_OrderLines_RID = L.ID
    inner join TripStops TS on TSD.ob_TripStops_RID = TS.ID
    inner join TripCalendar T on TS.ob_TripCalendar_RID = T.ID
    left outer join (select distinct T.ps_OrderLines_RID, D.drillNumber, U.unit
        from CADTransactions T inner join CADDrills D on T.ps_CADDrills_RID = D.ID
        inner join Units U on T.ps_TargetUnit_RID = U.ID) as Z
        on L.ID = Z.ps_OrderLines_RID
    left outer join (select distinct L.ID, CD.drillNumber
        from OrderLines L
        inner join OrderUnits OU on OU.ob_OrderLines_RID = L.ID
        left outer join CADDRILLS CD on CD.ID = OU.ps_CADDrills_RID) as Y on L.ID = Y.ID   
        
    where L.designStatus = 'Des' AND U.dateWorkPapersProcessed is null
    
    order by T.StartTime,T.tripNumber, TS.stopNumberStartingWith1, O.orderNumber, L.lineNumber
GO
