USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[N115Report]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[N115Report]

@noDays integer

as

declare @lastDate date = getDate()
declare @firstdate date
declare @historyStart date
set @firstDate = dateAdd(dd, -@Nodays, @lastDate)
set @historyStart = dateAdd(dd, -1, @firstDate)


select heading, N.oldCode as item, description, 
I.UMStock + isNull(distSold,0) + isNull(onlineFulfill,0) - isNull(inbound,0) as startingInventory,
H.UMStock as ActualStarting, H.dateUpdated,
case when I.UMStock + isNull(distSold,0) + isNull(onlineFulfill,0) - isNull(inbound,0) <> H.UMStock 
    then cast(( I.UMStock + isNull(distSold,0) + isNull(onlineFulfill,0) - isNull(inbound,0)) - H.UMStock as char(9))    else '' end as message,
isnull(distSold,0) as distSold, isNull(onlineFulfill, 0) as onLineFulFill,
isNull(inbound,0) as inbound, I.UMStock as EndingInventory, I.LFperUM


 from N115Items N inner join  ITEMS I on N.oldCode = I.oldCode

left outer join (
select I.oldCode, sum(case when C.oldCustNo <> 'N115' then customerQty else 0 end) as distSold,
sum(case when C.oldCustNo = 'N115' then customerQty else 0 end) as onlineFulfill 

from ORDERLINES L inner join ORDERS O on L.ob_Orders_RID = O.ID
inner join ITEMS I on L.ob_Items_RID = I.ID
inner join CUSTOMERS C on O.ob_Customers_RID = C.ID
where L.dateShipped between @firstDate and @lastDate
group by I.oldCode

) as Z on N.oldCode = Z.oldCode

left outer join (
select I.oldCode, sum(round(LFReceived,0)) as inBound

from PURCHASELINES L
inner join ITEMS I on L.ob_Items_RID = I.ID

where L.dateReceived between @firstDate and @lastDate
group by I.oldCode) as Y on N.oldCode = Y.oldCode

left outer join (select inventoryID, dateUpdated, oldCode, UMStock
    from InventoryDailyTotals where dateUpdated between @historyStart and @FirstDate
) as H on I.oldCode = H.oldCode

order by N.sortField
GO
