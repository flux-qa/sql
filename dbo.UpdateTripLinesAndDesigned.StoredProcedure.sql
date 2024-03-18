USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateTripLinesAndDesigned]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateTripLinesAndDesigned]

AS

Update TRIPCALENDAR
    set noOrderLines = Z.noLines, noOrderLinesComplete = Z.noDesigned,
    orderLinesMessage = case when ISNull(Z.noLines,0) = 0 then ''
    when Z.noLines = Z.noDesigned then 'Ready'
    else RTRIM(LTRIM(cast (Z.noDesigned as char(3)))) + ' of ' + RTRIM(LTRIM(cast(Z.noLines as char(3)))) end

from TRIPCALENDAR T inner join (
    select L.tripNumber, count(*) as noLines, sum(case when designStatus = 'W/P' AND O.holdShipments <> 1 then 1 else 0 end) as noDesigned
    from ORDERLINES L inner join Orders O on L.ob_Orders_RID = O.ID
    where UMShipped = 0 AND 
    L.tripNumber > 0
    group by L.tripNumber) as Z on T.tripNumber = Z.tripNumber
    
WHERE dateAdd(dd, -10, getdate()) < T.StartTime
and (status = 'Proposed' or status = 'Actual')
GO
