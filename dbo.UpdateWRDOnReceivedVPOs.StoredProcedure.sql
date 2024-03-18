USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateWRDOnReceivedVPOs]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateWRDOnReceivedVPOs]

as


update OrderLines set wrd = 'W'
from OrderLines L inner join PurchaseLines P on L.ps_PurchaseLines_RID = P.ID
where P.dateReceived is not null and L.wrd = 'R'

-- FOLLOWING ADDED 5/1/2022 TO HANDLE ROLLING WHOLE UNITS THAT ARE RECEIVED
Update OrderLines set WRD = 'W', SRO = 'S'
    from OrderLines L inner join OrderUnits OU on OU.ob_OrderLines_RID = L.ID
    inner join Units U on OU.ps_Units_RID = U.ID
    inner join PurchaseLines PL on U.ps_PurchaseLines_RID = PL.ID
    WHERE L.SRO = 'R' AND PL.dateReceived is not null


-- ONLY RUN THIS BEFORE 2:30 PM
IF ((DATEPART(HOUR, getDate()))  + DATEPART(MINUTE, getDate())) * 60 < 870 
BEGIN
-- 1ST CREATE TRIP STOP DETAILS FOR ANY ITEM THAT IS A VPO WHICH HAS A RECEIVED DATE
INSERT INTO [dbo].[TripStopDetails]([ID], [BASVERSION], [BASTIMESTAMP], 
    [ob_TripStops_REN], [ob_TripStops_RID], [ob_TripStops_RMA], 
    [ps_OrderLines_REN], [ps_OrderLines_RID], [ps_OrderLines_RMA], 
    [profit], [BMEs], 
    [BMEsperLB], [BMEsperFT3]) 

    select next Value For BAS_IDGEN_SEQ, 1, getdate(),
    'TripStops', TS.ID, 'om_TripStopDetails',
    'OrderLines', L.ID, 'ps_TripStopDetails',
    ROUND(L.UMOrdered * (L.actualPrice - L.projectedCost) / L.per,0), 
    L.BMEs, L.BMEsperLB, L.BMEsperFT3
        from OrderLines L inner join PurchaseLines PL on L.ps_PurchaseLines_RID = PL.ID
        inner join Orders O on L.ob_Orders_RID = O.ID
        inner join TripStops TS on O.ob_Customers_RID = TS.ps_Customers_RID
        inner join TripCalendar T on TS.ob_TripCalendar_RID = T.ID
        where L.dateShipped is null and L.tripNumber = 0 and
        PL.dateReceived IS NOT NULL AND
        (T.status = 'Actual' or T.status = 'Proposed')
    
-- 2ND UPDATE THE ORDERLINE WITH THE TRIPNUMBER AND TRIPDATEW
UPDATE OrderLines set tripNumber = T.tripNumber, tripDate = T.StartTime
    from OrderLines L inner join PurchaseLines PL on L.ps_PurchaseLines_RID = PL.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
    inner join TripStops TS on O.ob_Customers_RID = TS.ps_Customers_RID
    inner join TripCalendar T on TS.ob_TripCalendar_RID = T.ID
    where L.dateShipped is null and L.tripNumber = 0 and
    PL.dateReceived IS NOT NULL AND
    (T.status = 'Actual' or T.status = 'Proposed')
    
END
GO
