USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[COGSbyDateByItem]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[COGSbyDateByItem]
@fromDate   date,
@thruDate   date,
@itemCode   varchar(6)

as

set @itemCode = RTRIM(@itemCode) + '%'

select C.name, C.city, C.state, count(*) as noSales,
ROUND(sum(L.UMShipped * L.actualPrice / L.per),0) as totSales,
    ROUND(sum(L.UMShipped * L.materialCost / L.per),0) as totCost

    from OrderLines L inner join Items I on L.ob_Items_RID = I.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    where L.DateShipped between @fromDate and @thruDate
    and I.oldCode like @itemCode
    
    group by C.name, C.city, C.state
    order by C.name, C.city, C.state
GO
