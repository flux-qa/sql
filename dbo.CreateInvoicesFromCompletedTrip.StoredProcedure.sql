USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateInvoicesFromCompletedTrip]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateInvoicesFromCompletedTrip]
-- LAST CHANGE 05/06/23 TO MAKE TERMS AN OUTER JOIN
-- 11/04/23 -- ADDED LastDayOfMonthForEOM
@tripID         bigint
as


declare @pickupSalesTax     decimal(10,3)
declare @tripNumber         integer

select @tripNumber = tripNumber from TripCalendar where ID = @TripID

begin transaction
select @pickupSalesTax = localSalesTax from SYSTEMSETTINGS
 ;
 
with w as (select cast(TC.startTime as date) as dateShipped, L.ob_Orders_RID as orderID,
    round(sum(round(1.0 * case when L.ob_Items_RID > 10000 and L.ob_Items_RID < 10010 then 1 
        else L.UMShipped end * L.actualPrice / L.per,  2)) + MAX(ISNULL(SCTotalInvoice,0)),2)  as orderTotal
    from tripCalendar TC inner join TripStops TS on TS.ob_TripCalendar_RID = TC.ID
    inner join TripStopDetails TSD on TSD.ob_TripStops_RID = TS.ID
    inner join OrderLines L on TSD.ps_OrderLines_RID = L.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
    
    
left outer join (select L.ob_Orders_RID, sum(
    case when OLSC.priceMode = 'U/M' then ROUND(L.UMShipped * price / L.per,2) else price end) as SCTotalInvoice
    FROM OrderLineServiceCharges OLSC inner join OrderLines L on OLSC.ob_OrderLines_RID = L.ID
--    left outer join Units U on U.ps_OrderLines_RID = L.ID
--    left outer join (select ob_Units_RID, sum(length * (qtyOnHand + isNull(qtyShipped,0))) as unitLFShipped 
--        from UnitLengths group by ob_Units_RID) as Z on U.ID = Z.ob_units_RID
    GROUP BY L.ob_Orders_RID) as SC on SC.ob_Orders_RID = L.ob_Orders_RID         
    
    
    where TC.id = @tripID
    --AND O.ob_Customers_RID = O.originalShipTo_RID
    group by TC.startTime, L.ob_Orders_RID)


insert into invoices (ID, BASVERSION, BASTIMESTAMP, 
    ob_Customer_REN, ob_Customer_RID, ob_Customer_RMA,
    ob_BillTo_REN, ob_BillTo_RID, ob_BillTo_RMA,
    ps_OrderNumber_REN, ps_OrderNumber_RID, ps_OrderNumber_RMA,
    ps_TermsCode_REN, ps_TermsCode_RID, ps_TermsCode_RMA, 
    dateEntered,  invoiceDate, dateShipped, discountDate, dueDate,
    invoiceNumber, subTotal, salesTax, balance, seqNumber, invoiceNumberString, invoiceType,
    totalDiscount, totalCredit, totalPaid, tripNumber)



select  NEXT VALUE FOR BAS_IDGEN_SEQ, 1, getDate(),
    'Customers', C.ID, 'om_Invoices',
    'CustomerRelations', R.ID, 'om_Invoices',
    'Orders', O.ID, 'ps_OrderNumber',
    'Terms', T.ID, null,
    getDate(), w.dateShipped, w.dateShipped, dateAdd(dd, isNull(T.discountDays,0),  case when T.EOM > 0 then EOMONTH(w.dateShipped) else w.dateshipped end), 
    dateAdd(dd, isNull(T.daysTillDue,0), 
        case when T.EOM > 0 then EOMONTH(w.dateShipped, T.eom - 1 + 
        -- ADDED 11/04/23 IF TERMS HAS LAST DAY OF MONTH FOR EOM
        -- AND >= THAT DATE THEN ADD AN EXTRA MONTH
        case when T.lastDayOfMonthForEOM > 0 
        and day(w.dateShipped) >= T.lastDayOfMonthForEOM then 1 else 0 end) 
        else w.dateshipped end),   

    O.orderNumber, w.orderTotal, isNull(round(0.01 * w.orderTotal * 
        case when O.pickup = 1 and C.salesTaxPct > 0 then @pickupSalesTax else C.salesTaxPct end,2),0),
    w.orderTotal + isNull(round(0.01 * w.orderTotal * 
        case when O.pickup = 1 and C.salesTaxPct > 0 then @pickupSalesTax else C.salesTaxPct end,2),0), isNull(lastSeq,-1) + 1,
    rtrim(cast(O.orderNumber as char(7))) + case when lastSeq is null then '' else
        '-' + rtrim(cast(lastSeq + 1 as char(2))) end, 'Invoice', 0, 0, 0, @tripNumber


from W inner join Orders O on W.orderID = O.ID
inner join CustomerRelations R on O.ob_BillTo_RID = R.ID
inner join Customers C on O.ob_Customers_RID = C.ID
left outer join Terms T on R.whseTerms_RID = T.ID
left outer join (select invoiceNumber, max(seqNumber) as lastSeq
    from Invoices group by invoiceNumber) as Z on O.orderNumber = Z.invoiceNumber

WHERE C.contractorFlag <> 1    
 
commit Transaction


Update OrderLines set dateInvoiced = cast(TC.startTime as date), invoiceSeqNumber = I.seqNumber
    from tripCalendar TC inner join TripStops TS on TS.ob_TripCalendar_RID = TC.ID
    inner join TripStopDetails TSD on TSD.ob_TripStops_RID = TS.ID
    inner join OrderLines L on TSD.ps_OrderLines_RID = L.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Invoices I on I.ob_Customer_RID = O.ob_Customers_RID and I.tripNumber = @tripNumber
           
    where TC.id = @tripID
    AND O.ob_Customers_RID = O.originalShipTo_RID
    
Update Orders set dateInvoiced = cast(TC.startTime as date)
    from tripCalendar TC inner join TripStops TS on TS.ob_TripCalendar_RID = TC.ID
    inner join TripStopDetails TSD on TSD.ob_TripStops_RID = TS.ID
    inner join OrderLines L on TSD.ps_OrderLines_RID = L.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
           
    where TC.id = @tripID
    AND O.ob_Customers_RID = O.originalShipTo_RID
GO
