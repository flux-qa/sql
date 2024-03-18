USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadCustomerDashboard]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadCustomerDashboard]

@FieldRep   char(5),
@TripID     integer = 0,
@filterFlag integer = 0

as

if @fieldrep = 'bruce' set @fieldRep = 'br'

select C.ID, 1 as BASVERSION, getDate() as BASTIMESTAMP,  ranking, tier, branch,
C.name, C.add1, C.city, C.state, 
lastShipment, isNULL(C.BMEs,0) as BMEs, 
case when lastYearSales is null or lastYearSales = 0 then null 
    when lastYearSales * 2 < currentSales then 100
    else round(100.0 * (currentSales - lastYearSales) / lastYearSales,0) end as trend,

case when currentProfit > 0 and currentSales > 0 
    then round(100.0 * currentProfit / currentSales,1) else null end as profitPct,

-- IF MIN BMES THEN ALL QTY (SHIPPABLE AND UNSHIPPABLE SHOWS UP AS UNSHIPPED AND NONE IS SHIPPABLE
case when S.maxStops > 0 and C.BMEs is not null and 12 / S.maxStops > C.BMEs 
    then unshipped else UMNoStock end as unShippable, 
case when S.maxStops > 0 and C.BMEs is not null and 12 / S.maxStops > C.BMEs 
    then null else unShipped - UMNoStock end as shippable,

case when UMNoStock > 0 then format(UMNoStock,'#,###') +  ' OOS'
when S.maxStops > 0 and C.BMEs is not null and 12 / S.maxStops > C.BMEs then format(unShipped, '#,###') + ' MIN'
else '' end as unshippableMsg,
dateAdd(dd, case when datePart(mm, getDate()) = 12 or datePart(mm, getDate()) < 4 then
    21 else 7 end + 457 / isNull(noOrderDays,1), 
    case when C.dateOfLastContact is NULL or lastOrder > C.dateOfLastContact 
        then lastOrder else C.dateOfLastContact end) as projectedDateNextContact,
round(case when datePart(mm, getDate()) = 12 or datePart(mm, getDate()) < 4 then
    21 else 7 end + 457 / isNull(noOrderDays,1),0) as avgDaysBetweenContacts,


ISNULL(convert (char(11), dateLastPayment, 0), '') as dateLastPayment, round(isNull(C.balance,0),0) as balance, round(isNull(balanceOverDue,0),0) as balanceOverDue,
case when C.balance IS NULL or C.balance < 1 
    then '----' else format(C.balance,'###,##0') end as balanceString,
case when balanceOverDue IS NULL or balanceOverDue < 1 
    then '----' else '<span style="color: red; font-weight: bold;">' +format(balanceOverDue, '###,##0') + '</span>' end as balanceOverDueString,
C.ps_Sector_RID, C.ps_Sector_RMA, C.ps_Sector_REN,
 dateFieldRepChanged, deliveryComments, lastShipment, projectedDateNextContact, 
 maxDaysForDating, dateInactivated, oldCustNo, creditLimit, unShippedShippableLines, 
 avgDaysBetweenContacts, email, ranking, unshippedFreight, unshippedLines, oldBillToCode, 
 currentProfit, minShippableSaleAmount, balanceOverDue, noOrderDays, unshippedDesignedLines, 
 unshippedProfit, custno, unshippableMsg, dateLastChange, unshippedTrippedLines, fieldRep, 
  fax, whseTerms_REN, whseTerms_RID, whseTerms_RMA, unshippedCost, 
 ps_Sector_REN, ps_Sector_RID, ps_Sector_RMA, shippable, lastOrder, lastYearSales, 
 active,  dateAdded, trend, previousFieldRep, creditAvailable, 
 pctToOverShip, balanceOverDueString, dateLastPayment, annualSales, billTo, 
 currentSales, unshippedSales, designComments, phone, tier, outOfBusiness, balance, 
 handlingMultiplier,  unShippable, balanceString, noBillToRecords, profitPct, 
 dateOfLastContact,  directTerms_REN, directTerms_RID, directTerms_RMA, 
 creditLimitRule,  unshippedBMEs, salesTaxPct, resaleCertificate, outsideFieldRep, BMEsperLB, BMEsperFT3,
 add2, C.zip, C.maxStops, C.holdDesign, C.altDeliveryLocation, C.contractorFlag, 
 C.reloadCustomer, shippingManifestComments, zeroMaterialCosts, C.lastYearNoOfReturns, C.lastYearNoCustomerRequestReturns,
 C.marketingExpensePct, C.truckManifestMessage,
 fromREST, toRest, lat, long, restReply, nomaterialCostfor3PL, shortName




from CUSTOMERS C
left outer join SECTORS S on C.ps_Sector_RID = S.ID 

-- COMPUTE THE SHIPPABLE AND UNSHIPPABLE (IF NO STOCK) FOR OPEN ORDERS
left outer join (select O.ob_Customers_RID as custID, min(O.estDeliveryDate) as estDeliveryDate,
    round(sum(L.UMOrdered * L.actualPrice / L.per),0) as unShipped,
    round(0.001 * sum(L.UMOrdered / I.LFperUM * I.LFperBME),1) as BMEs,
    round(sum(case when L.UMOrdered > I.UMStock then L.UMOrdered * L.actualPrice / L.per else null end),0) as UMNoStock

    from ORDERS O inner join ORDERLINES L on L.ob_Orders_RID = O.ID
    inner join ITEMS I on L.ob_Items_RID = I.ID
    where L.dateShipped is null and L.per > 0 and I.LFperUM > 0
    group by O.ob_Customers_RID) as Y on C.ID = Y.custID


WHERE(active = 'A' and left(C.name,1) <> '[' and 
(left(C.fieldRep,2) = @FieldRep OR left(C.outsideFieldRep,2) = @FieldRep)) AND 
 
 (@tripID = 0 or ps_Sector_RID in (select distinct C.ps_Sector_RID as sector
    from TRIPCALENDAR T inner join TRIPSTOPS TS on TS.ob_TripCalendar_RID = T.ID
    inner join CUSTOMERS C on TS.ps_Customers_RID = C.ID
    where T.ID = @TripID and ps_Sector_RID IS NOT NULL))

and (@filterFlag = 0 or (projectedDateNextContact is not null and projectedDateNextContact < getDate()))

order by name, city
GO
