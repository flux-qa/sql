USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[OneItemShippedLengths]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OneItemShippedLengths]
  
  

@oldcode        varchar(4)  = 'A336',
@firstDate      date    = '11/01/2021',
@lastDate       date    = '11/30/2021'

as 
;

with w as (select O.originalShipTo_RID as custno, UL.length, sum(UL.qtyShipped) as pcsShipped
    from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Units U on U.ps_OrderLines_RID = L.ID
    inner join UnitLengths UL on UL.ob_Units_RID = U.ID
    inner join Items I on L.ob_Items_RID = I.ID
    
    WHERE I.oldcode = @oldCode and cast(L.dateShipped as date) between @firstDate and @lastDate
    group by O.originalShipTo_RID, ul.length)
    
    
select C.name, C.city, STRING_AGG(cast(pcsShipped as varchar(5)) + '/' + cast(length as varchar(2)) + ''''  , ' , ') as shipped

    from (select top 100000 * from W order by custno, length) as Z inner join Customers C on Z.custno = C.ID
    group by C.name, C.city
    order by c.name, c.city
GO
