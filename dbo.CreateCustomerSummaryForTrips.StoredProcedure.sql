USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateCustomerSummaryForTrips]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateCustomerSummaryForTrips]
  
-- LAST CHANGE 02/10/17
@tripNo integer

as


declare @today date 
set @today = cast(getdate() as date)

Delete From CUSTOMERSUMMARYFORTRIPS

INSERT INTO [dbo].[CUSTOMERSUMMARYFORTRIPS]
    ([ID], [BASVERSION], [BASTIMESTAMP], 
    custno, customerName, city, state, soonestDue, soonestDeadline, saleTotal, grossProfit, sectorID, sectorName, 
    noLines, noOrders, BMEs, BMEsperFT3, BMEsperLB, sectorOnTrip, isDeadline, isNoSooner, hasPickup, hasContractServices, CODFlag, contractServiceReady)

select max(C.ID) as ID, max(1) as BASVERSION, 
max(getDate()) as BASTIMESTAMP,
C.id as custno, C.name as customerName, C.city, C.state, ISNULL(min(O.deadline),min(O.estDeliveryDate)) as soonestDue,
min(O.deadline) as soonestDeadline, 
cast(sum(L.customerQty * L.actualPrice  / L.per) as integer) as saleTotal,
cast(sum(L.customerQty * (L.actualPrice - L.projectedCost) / L.per) as integer) as grossProfit,
S.ID as sectorID, S.name as sectorName, 
count(*) as noLines, count(distinct L.ob_Orders_RID) as noOrders, Round(sum(L.BMEs) / 100, 0) / 10.0 as BMEs,
sum(L.BMEsperFT3), sum(L.BMEsperLB),
case when max(isNull(SOT.sectorID,0)) = 0 then 0 else 1 end, 
max(case when O.deadline is null then 0 else 1 end) as isDeadline,
max(case when O.deferred is null then 0 else 1 end) as isNoSooner,
max (case when O.pickup = 1 then 1 else 0 end),
max (case when L.ps_LinkToContractorOrderLine_RID is not null then 1 else 0 end), 
max(case when left(T.description,1) = 'C' then 1 else 0 end),
max (case when L.ps_LinkToContractorOrderLine_RID is not null AND (I.UMStock >= L.UMOrdered OR L.designStatus <> '') then 1 else 0 end)


from CUSTOMERS C inner join SECTORS S on C.ps_Sector_RID = S.ID
inner join ORDERS O on O.ob_Customers_RID = C.ID
inner join CustomerRelations R on O.ob_BillTo_RID = R.ID
left outer join Terms T on R.whseTerms_RID = T.ID
inner join ORDERLINES L on L.ob_Orders_RID = O.ID
left outer join PurchaseLines P on L.ps_PurchaseLines_RID = P.ID
inner join ITEMS I on L.ob_Items_RID = I.ID
left outer join SectorsOnTrip SOT on SOT.tripID = @TripNo AND C.ps_sector_RID = SOT.sectorID

where L.UMShipped = 0  and (I.UMStock >= L.UMOrdered * 0.91 OR L.designStatus <> '') 
    and O.holdDesign <> 1 and O.pickup = 0
    and L.tripNumber = 0 
    and L.WRD <> 'D'
    and (O.deferred IS NULL OR O.deferred <= dateAdd(dd, 5, getdate())) -- Added 02/05/2020
    and (O.shipComplete <> 1 OR O.noLines <= O.noOrderLinesW) -- Added 07/30/22
--    and (I.ID < 10000 or I.ID > 10010)      -- ADDED 09/10/19
    and (L.ps_PurchaseLines_RID IS NULL or P.dateReceived is not null)



and C.ID not in  
    (select ISNULL(ps_Customers_RID,0) from TRIPSTOPS TS
        inner join TRIPCALENDAR T on TS.ob_TripCalendar_RID = T.ID
        where (T.status = 'Proposed' OR T.status = 'Actual')
        )

/*
and C.ID not in (select ob_Customers_RID from TRIPSTOPS
    where ob_TripCalendar_RID = @TripNo)
*/
group by C.ID, C.name, S.ID, S.name, C.city, C.state
order by  S.ID, S.name, C.name, C.ID

update customerSummaryForTrips

set grossProfit = grossProfit -
case when C.contractorFlag = 1 then grossProfit else 0 end

from CustomerSummaryForTrips CS inner join Customers C on CS.custno = C.ID
inner join Sectors S on C.ps_Sector_RID = S.ID



-- DELETE ANY RECORDS WHERE THERE IS ONLY FREIGHT / MISC. LINES
delete from CustomerSummaryForTrips where id not in (
select O.ob_Customers_RID 
from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
inner join Items I on L.ob_Items_RID = I.ID
left outer join PurchaseLines P on L.ps_PurchaseLines_RID = P.ID
where L.UMShipped = 0  and (I.UMStock  >= L.UMOrdered * 0.91 OR L.designStatus <> '') 
    and O.holdDesign <> 1 and O.pickup = 0
    and L.tripNumber = 0 and L.WRD <> 'D'
    and (I.ID < 10000 or I.ID > 10010)      -- ADDED 09/10/19
    and (L.ps_PurchaseLines_RID IS NULL or P.dateReceived is not null)
)
GO
