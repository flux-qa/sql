USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ImportTerminalSalesOrders]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[ImportTerminalSalesOrders]
as
declare @vendorNumber integer
select @vendorNumber = ID from VENDORS where name like '%terminal%'

delete from TERMINALSALESORDERS

insert into TERMINALSALESORDERS (id, BASVersion, BASTIMESTAMP,
    ob_TerminalItems_REN, ob_TerminalItems_RID, ob_TerminalItems_RMA,
    ordered, shipped, entryDate, balance, salesOrderDate)
select row_number() over (order by P.ID), 1, getDate(),
    'TerminalItems', T.ID, 'ob_TerminalItems',
    ROUND(L.LFOrdered * I.LFtoUM,0), 0,  getdate(), ROUND(L.LFOrdered * I.LFtoUM,0), P.dateEntered
    from PURCHASELINES L inner join ITEMS I on L.ob_Items_RID = I.ID
    inner join PURCHASEORDERS P on L.ob_PurchaseOrders_RID = P.ID
    inner join TERMINALITEMS T on T.ps_Item_RID = I.ID
    where P.ob_Vendors_RID = @vendorNumber and P.dateEntered > dateadd(dd, -720, getdate())
    order by P.ID

delete from TERMINALSHIPMENTS

    insert into TERMINALSHIPMENTS (id, BASVersion, BASTimeStamp,
        ob_TerminalItems_REN, ob_TerminalItems_RID, ob_TerminalItems_RMA,
        ps_TerminalSalesOrders_REN, ps_TerminalSalesOrders_RID, ps_TerminalSalesOrders_RMA,
        quantity, entryDate)

select row_number() over (order by P.ID), 1, getDate(),
    'TerminalItems', T.ID, 'ob_TerminalItems',
    'TerminalSalesOrders', null, null,

    ROUND(totLF * I.LFtoUM,0),  p.dateEntered
    from PURCHASELINES L inner join ITEMS I on L.ob_Items_RID = I.ID
    inner join PURCHASEORDERS P on L.ob_PurchaseOrders_RID = P.ID
    inner join TERMINALITEMS T on T.ps_Item_RID = I.ID
    inner join (select U.ps_purchaseOrders_RID, sum(L.length * (qtyShipped + qtyOnHand)) as totLF
    from UNITS U inner join UNITLENGTHS L on L.ob_Units_RID = U.ID 
    group by U.ps_PurchaseOrders_RID ) as Z on Z.ps_PurchaseOrders_RID = P.ID
    where P.ob_Vendors_RID = @vendorNumber and P.dateEntered > dateadd(dd, -720, getdate())


declare @ID integer, @item integer, @salesOrder integer, @quantity integer

update TERMINALITEMS set totalReceived = 0, totalSalesOrder = 0, balance = 0

declare myCursor cursor local for
    select id, ob_terminalItems_RID, quantity from TERMINALSHIPMENTS
        order by ID

open myCursor
fetch next from myCursor into @ID, @Item, @quantity

while (@@fetch_Status = 0)
begin

    select top 1 @salesOrder = ID from TERMINALSALESORDERS 
        where ob_TerminalItems_RID = @Item and balance >= @quantity
        order by ID

    update TERMINALSALESORDERS set balance = balance - @quantity, 
        shipped = shipped + @quantity
        where ID = @SalesOrder

    update TERMINALSHIPMENTS set ps_TerminalSalesOrders_RID = @SalesOrder
        where ID = @ID
    
    fetch next from myCursor into @ID, @Item, @quantity
end
close myCursor
deallocate myCursor

Update TERMINALITEMS
    set totalSalesOrder = ordered, totalReceived = shipped, balance = ordered - shipped

from TERMINALITEMS I inner join (select ob_TerminalItems_RID, 
    sum(ordered) as ordered, sum(shipped) as shipped
from TERMINALSALESORDERS group by ob_TerminalItems_RID) as Z on Z.ob_TerminalItems_RID = I.ID
GO
