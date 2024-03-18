USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[SalesOfNItemsForPeriod]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SalesOfNItemsForPeriod]
@fromDate date,
@thruDate date,
@searchString   varchar(5) = 'N%'

as

with w as (select C.ID as custno, count(*) as noLines, 
    round(sum(L.UMShipped * L.actualPrice / L.per),2) as saleAmount
    from orderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    inner join Items I on L.ob_Items_RID = I.ID
    left outer join Sectors S on C.ps_Sector_RID = S.ID
    
    where L.dateShipped between @fromDate and @thruDate
    and I.oldcode like @searchString
    group by c.id
)

select C.oldCustNo as code, C.name, C.city, C.state, S.name as sector, 
    w.noLines, w.saleAmount   
    from Customers C inner join W on C.ID = W.custno
    left outer join Sectors S on C.ps_Sector_RID = S.ID   
    order by C.name
GO
