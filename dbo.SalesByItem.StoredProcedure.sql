USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[SalesByItem]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create Procedure [dbo].[SalesByItem]        
        
        @firstDate  date = '01/01/2019',
        @lastDate   date = '12/31/2019',
        @item       varchar(6) = '0Q'
 as
        
set @item = rtrim(ltrim(@item)) + '%'
; 
with w as (select O.orderNumber as orderNo, C.name, C.city,
    I.oldCode as code, I.internalDescription as item, cast(L.dateShipped as date) as shipped,
    L.UMShipped as qty, I.UM, round(L.UMShipped * L.actualPrice / L.per,2) as amount
    from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    inner join Items I on L.ob_Items_RID = I.ID
    where L.dateShipped between @firstDate and @lastDate
    and I.oldCode like @item)
    
    select orderNo, name, city, W.code, item, shipped, qty, UM, amount, noLines, totQty, totAmount
    from W inner join (select code, count(*) as noLines, sum(qty) as totQty, sum(amount) as totAmount from W group by code) as Z
        on W.code = Z.code
    order by W.code, shipped, name
GO
