USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateOrderTotalAndSalesTax]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateOrderTotalAndSalesTax]

@orderID            integer = 0,
@tripNumber         integer = 0,
@invoiceSeqNumber   integer = 0

as

declare @salesTaxPct decimal(10,4)

select @salesTaxPct = localSalesTax from SYSTEMSETTINGS

update Orders set orderTotal =  ROUND(X.totalInvoice,2) + ROUND(isNull(SCTotalInvoice,0),2) ,
    salesTax = ROUND(case when isNull(C.salesTaxPct,0) = 0 then 0 when O.pickup = 1 then @salesTaxPct else isNull(C.salesTaxPct,0) end 
        * (X.totalInvoice + isNull(SCTotalInvoice,0)) * 0.01,2) 

from OrderLines L
inner join Orders O on O.ID = L.ob_Orders_RID
inner join Customers C on O.ob_Customers_RID = C.ID
inner join Items I on L.ob_Items_RID = I.ID
left outer join Units U on U.ps_OrderLines_RID = L.ID
        
inner join (select ID,  sum(totalInvoice) as totalInvoice from (
    select O.ID,   ROUND(case when L.ob_Items_RID > 10000 and L.ob_Items_RID < 10010 then 1 else 
        ROUND(totLFShipped * 1.0 / I.LFperUM + 0.0001 ,0) end * L.actualPrice / L.per + 0.0001,2) as totalInvoice
        from Orders O inner join OrderLines L on O.ID = L.ob_Orders_RID
        inner join Items I on L.ob_items_RID = I.ID
        left outer join (
            select U.ps_OrderLines_RID, 
            sum(L.length * (L.qtyOnHand + L.qtyShipped)) as totLFShipped from Units U 
            inner join UnitLengths L on L.ob_Units_RID = U.ID
            inner join OrderLines OL on U.ps_OrderLines_RID = OL.ID
            inner join Orders O on OL.ob_Orders_RID = O.ID
            where (@orderID = 0 OR O.ID = @orderID) AND (@tripNumber = 0 OR OL.tripNumber = @tripNumber) and (OL.invoiceSeqNumber = @invoiceSeqNumber)
            group by U.ps_OrderLines_RID
            ) as Z on L.ID = Z.ps_OrderLines_RID
        where (@orderID = 0 OR O.ID = @orderID) AND (@tripNumber = 0 OR L.tripNumber = @tripNumber) and (L.invoiceSeqNumber = @invoiceSeqNumber)
        ) as Y group by ID) as X on X.ID = O.ID 

left outer join (select L.ob_Orders_RID, sum(
    case when OLSC.priceMode = 'U/M' then ROUND(L.UMShipped * price / L.per,2) else price end) as SCTotalInvoice
    FROM OrderLineServiceCharges OLSC inner join OrderLines L on OLSC.ob_OrderLines_RID = L.ID
--    left outer join Units U on U.ps_OrderLines_RID = L.ID
--    left outer join (select ob_Units_RID, sum(length * (qtyOnHand + isNull(qtyShipped,0))) as unitLFShipped 
--        from UnitLengths group by ob_Units_RID) as Z on U.ID = Z.ob_units_RID
        group by L.ob_Orders_RID) as SC on SC.ob_Orders_RID = O.ID    
    

where (@orderID = 0 OR O.ID = @orderID) AND (@tripNumber = 0 OR L.tripNumber = @tripNumber) 
    and (U.ID is not null or (I.id > 10000 and I.ID < 10010))
GO
