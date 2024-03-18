USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UsagebyDateByItem]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UsagebyDateByItem]
@fromDate   date,
@thruDate   date,
@itemCode   varchar(6)

as

set @itemCode = RTRIM(@itemCode) + '%'

select I.oldcode as code, I.internalDescription as item, count(*) as noSales,
    sum(L.umShipped) as shipped,
ROUND(sum(L.UMShipped * L.actualPrice / L.per),0) as totSales,
    ROUND(sum(L.UMShipped * L.materialCost / L.per),0) as totCost


    from OrderLines L inner join Items I on L.ob_Items_RID = I.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    where L.DateShipped between @fromDate and @thruDate
    and I.oldCode like @itemCode
    
    group by I.oldCode, I.internalDescription
    order by I.oldCode, I.internalDescription
GO
