USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[Invoice1Order]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Invoice1Order]

@orderID        bigint,
@directFlag     int = 0
as


IF @directFlag = 0 exec UpdateOrderTotalAndSalesTax @orderID
IF @directFlag = 1 exec UpdateOrderTotalAndSalesTaxDirects @orderID

declare @orderTotal Decimal(15,2)

select @orderTotal = orderTotal from Orders where ID = @orderID
if @orderTotal is NULL OR @orderTotal = 0 
    RETURN 0


declare @pickupSalesTax decimal(10,3)

select @pickupSalesTax = localSalesTax from SYSTEMSETTINGS
 ;
 
    
insert into invoices (ID, BASVERSION, BASTIMESTAMP, 
    ob_Customer_REN, ob_Customer_RID, ob_Customer_RMA,
    ob_BillTo_REN, ob_BillTo_RID, ob_BillTo_RMA,
    ps_OrderNumber_REN, ps_OrderNumber_RID, ps_OrderNumber_RMA,
    ps_TermsCode_REN, ps_TermsCode_RID, ps_TermsCode_RMA, 
    dateEntered,  invoiceDate, dateShipped, discountDate, dueDate,
    invoiceNumber, subTotal, salesTax, balance, seqNumber, invoiceNumberString, invoiceType,
    totalDiscount, totalCredit, totalPaid)

select  NEXT VALUE FOR BAS_IDGEN_SEQ , 1, getDate(),
    'Customers', C.ID, 'om_Invoices',
    'CustomerRelations', R.ID, 'om_Invoices',
    'Orders', O.ID, 'ps_OrderNumber',
    'Terms', T.ID, null,
    getDate(), O.dateShipped, O.dateShipped, dateAdd(dd, isNull(T.discountDays,0), case when isNull(T.EOM,0) > 0 then EOMONTH(O.dateShipped, T.eom - 1) else O.dateshipped end), 
    dateAdd(dd, isNull(T.daysTillDue,30), 
    case when isNull(T.EOM,0) > 0 then EOMONTH(O.dateShipped, T.eom - 1 +
    -- ADDED 11/04/23 IF TERMS HAS LAST DAY OF MONTH FOR EOM
    -- AND >= THAT DATE THEN ADD AN EXTRA MONTH
    case when T.lastDayOfMonthForEOM > 0 
        and day(O.dateShipped) >= T.lastDayOfMonthForEOM then 1 else 0 end)    
    else O.dateshipped end),   

    O.orderNumber, O.orderTotal, isNull(round(0.01 * O.orderTotal * case when O.pickup = 1 and C.salesTaxPct > 0 then  @pickupSalesTax else C.salesTaxPct end,2),0),
    O.orderTotal + isNull(round(O.orderTotal * 
        case when O.pickup = 1 and C.salesTaxPct > 0 then 0.01 * @pickupSalesTax else 0.01 * C.salesTaxPct end,2),0), isNull(lastSeq,-1) + 1,
    rtrim(cast(O.orderNumber as char(7))) + case when lastSeq is null then '' else
        '-' + rtrim(cast(lastSeq + 1 as char(2))) end, case when @directFlag = 1 then 'Direct' else 'Invoice' end, 0, 0, 0


from Orders O 
inner join CustomerRelations R on O.ob_BillTo_RID = R.ID
inner join Customers C on O.ob_Customers_RID = C.ID
left outer join Terms T on case when @directFlag = 1 then R.directTerms_RID else R.whseTerms_RID end = T.ID
left outer join (select invoiceNumber, max(seqNumber) as lastSeq
    from Invoices group by invoiceNumber) as Z on O.orderNumber = Z.invoiceNumber

WHERE O.ID = @orderID
--    AND O.ob_Customers_RID = O.originalShipTo_RID
    AND C.contractorFlag <> 1


update Orders set dateInvoiced = dateshipped 
from Orders O 
    where O.ID = @orderID
    
Update OrderLines set dateInvoiced = O.dateShipped
    from Orders O inner join OrderLines L on L.ob_Orders_RID = O.ID
    where O.ID = @orderID
GO
