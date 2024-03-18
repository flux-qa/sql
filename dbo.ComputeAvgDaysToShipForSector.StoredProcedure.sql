USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ComputeAvgDaysToShipForSector]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ComputeAvgDaysToShipForSector]
@FromDate date,
@ThruDate date
AS

 with w as (select S.ID as sector, C.oldCustNo as custno, 
	datediff(dd, dateEntered, dateShipped) - (datediff(wk, dateEntered, dateShipped) * 2) -
       case when datepart(dw, dateEntered) = 1 then 1 else 0 end +
       case when datepart(dw, dateShipped) = 1 then 1 else 0 end
	as daysToShip

	from Orders O 
	inner join Customers C on O.ob_Customers_RID = C.ID
	inner join Sectors S on C.ps_Sector_RID = S.ID
	where O.dateShipped between @FromDate and @ThruDate
)

update Sectors set avgDaysFromOrderToShipped = avgDays
	from Sectors S inner join (select w.sector, 
    min(daysToShip) as minDays, max(daysToShip) as maxDays,
    round(avg(1.0 * daysToShip), 0) as avgDays,
    count(*) as noOrders, count(distinct custno) as noCusts
    from W where daysToShip > 0 and daysToShip < 10 group by w.sector) as Z on Z.sector = S.ID
GO
