USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ShipToBillToItemTotals]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ShipToBillToItemTotals]


    @shipToName varchar(200),
    @billToName varchar(200),
    @item       varchar(6),
    @fromDate   date = '01/01/2021',
    @thruDate   date = '12/31/2021'
    
as
    
set @shipToName = RTRIM(@shipToName) + '%'
set @billTOName = RTRIM(@billToName) + '%'
set @item = RTRIM(@item) + '%'

select C.name, I.oldcode as code, I.internalDescription as item, count(*) as noOrders, sum(UMOrdered) as UMOrdered, max(I.UM) as UM

    from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Items I on L.ob_Items_RID = I.ID
    inner join Customers C on O.originalShipTo_RID = C.ID
    inner join CustomerRelations R on O.ob_BillTo_RID = R.ID
    where L.dateShipped between @fromdate AND @thruDate
    AND I.oldcode like @item
    AND C.name like @shipToName
    and R.name like @billToName
    group by C.name, I.oldCode, I.internalDescription
    order by C.name, I.oldCode
GO
