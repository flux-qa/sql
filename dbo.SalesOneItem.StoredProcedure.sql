USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[SalesOneItem]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SalesOneItem]

    @itemcode       varchar(5),
    @fromDate       date,
    @thruDate       date
as
    
select C.name, C.city, sum(L.UMShipped) as UMShipped
    from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    inner join Items I on L.ob_Items_RID = I.ID
    where I.oldCode = @itemCode
    and cast(L.dateShipped as date) between @fromDate and @thruDate
    group by C.name, C.city
    order by C.name, C.city
GO
