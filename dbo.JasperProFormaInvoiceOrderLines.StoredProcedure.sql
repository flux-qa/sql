USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[JasperProFormaInvoiceOrderLines]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[JasperProFormaInvoiceOrderLines]

@orderID integer = 1148146,
@tripNumber integer = 0

as

-- last change 12/19/23

declare @salesTaxPct decimal(10,4)

select @salesTaxPct = localSalesTax
    from SYSTEMSETTINGS

select L.ID as ID, L.lineNumber,  L.customerQty, L.customerUM, L.actualPrice,
L.perString,  L.additionalInvoiceComments, L.comments,  
case when L.itemOrSeagullDescription is null or L.itemOrSeagullDescription = '' 
  then RTRIM(I.internalDescription) + 
    case when L.additionalInvoiceComments <> '' then ' ' + rtrim(L.additionalInvoiceComments) else '' end 
    else L.itemOrSeagullDescription + 
    case when L.additionalInvoiceComments <> '' then ' ' + rtrim(L.additionalInvoiceComments) else '' end 
    end as internalDescription, 
I.UM, L.per,  case when (I.id > 10000 and I.ID < 10010) then 1
    when @tripNumber = 0 and  ROUND(Y.LFShipped / I.LFperUM,0) > 0 then ROUND(Y.LFShipped / I.LFperUM,0) when @tripNumber = 0 and L.UMShipped = 0 then UMOrdered
    when L.WRD = 'D' then L.UMShipped 
    else ROUND(Y.LFShipped / I.LFperUM,0) end as umShipped, 
qtyFormatted, priceFormatted,
I.oldCode as item, ob_Units_RID,  
Y.LFShipped as totLFShipped, (U.UMStock + U.UMShipped) as unitUMShipped, 
case when (I.id > 10000 and I.ID < 10010) then actualPrice
    else ROUND(0.0001 +  ROUND(1.0 * 
    (case when L.WRD = 'D' then L.UMShipped
     when @tripNumber = 0 and  ROUND(Y.LFShipped / I.LFperUM,0) > 0 then ROUND(Y.LFShipped / I.LFperUM,0) when @tripNumber = 0 and L.UMShipped = 0 then UMOrdered 
     else (Y.LFShipped / I.LFperUM) end
     + 0.00001),0) * L.actualPrice / L.per,2) end as lineTotal, 
CASE WHEN L.WRD = 'D' OR @tripNumber = 0 then D.directTotal else X.totalInvoice end + 
    isNull(SCTotalInvoice,0) as invoiceTotal, isnull(U.unit,'') as unit,
isnull(dbo.UnitTallyPlusShippedToString(U.ID),'') as tallyString, ROUND(
    case when isNull(C.salesTaxPct,0) = 0 then 0 when O.pickup = 1 then @salesTaxPct else isNull(C.salesTaxPct,0) end 
    * (CASE WHEN L.WRD = 'D' or @tripNumber = 0 then D.directTotal else X.totalInvoice end + isNull(SCTotalInvoice,0)) * 0.01,2) as salesTax,
    dbo.ServiceChargeDescripionFor1Line(L.ID) as serviceChargeDescription


from OrderLines L
inner join Orders O on O.ID = L.ob_Orders_RID
inner join Customers C on O.ob_Customers_RID = C.ID
inner join Items I on L.ob_Items_RID = I.ID

left outer join Units U on U.ps_OrderLines_RID = L.ID
left outer join (select ob_Units_RID, sum(length * (qtyOnHand + isNull(qtyShipped,0))) as unitLFShipped 
    from UnitLengths group by ob_Units_RID) as Z on U.ID = Z.ob_units_RID



left outer join (select U.ps_OrderLines_RID, sum(L.length * (L.qtyOnHand + L.qtyShipped)) as LFShipped 
    from  Units U inner join UnitLengths L on L.ob_Units_RID = U.ID
    inner join Items I on U.ob_Items_RID = I.ID   
    group by U.ps_OrderLines_RID) as Y on L.ID = Y.ps_OrderLines_RID

        
left outer join (select sum(totalInvoice) as totalInvoice from (select 
    ROUND(case when L.ob_Items_RID > 10000 and L.ob_Items_RID < 10010 then 1 else 
        ROUND(totLFShipped * 1.0 / I.LFperUM + 0.0001 ,0) end * L.actualPrice / L.per + 0.0001,2) as totalInvoice
    from Orders O inner join OrderLines L on O.ID = L.ob_Orders_RID
    inner join Items I on L.ob_items_RID = I.ID
    left outer join (select U.ps_OrderLines_RID, 
        sum(L.length * (L.qtyOnHand + L.qtyShipped)) as totLFShipped from Units U 
        inner join UnitLengths L on L.ob_Units_RID = U.ID
        group by U.ps_OrderLines_RID) as Z on L.ID = Z.ps_OrderLines_RID
     where L.ob_Orders_RID = @orderID AND (@TripNumber = 0 OR @tripNumber = L.tripNumber)) as X1) as X on 1 = 1
     
left outer join (select 
    sum(case when ROUND(Y.LFShipped / I.LFperUM,0) > 0 then ROUND(Y.LFShipped / I.LFperUM,0) when @tripNumber = 0 and L.UMShipped = 0 then UMOrdered else L.UMShipped end
     * actualPrice / per) as directTotal
    from OrderLines L  inner join Items I on L.ob_items_RID = I.ID
     
     left outer join (select U.ps_OrderLines_RID, sum(L.length * (L.qtyOnHand + L.qtyShipped)) as LFShipped 
    from  Units U inner join UnitLengths L on L.ob_Units_RID = U.ID
    inner join Items I on U.ob_Items_RID = I.ID   
    group by U.ps_OrderLines_RID) as Y on L.ID = Y.ps_OrderLines_RID
     
     where L.ob_Orders_RID = @orderID) as D on 1 = 1    

left outer join (select sum(
    case when OLSC.priceMode = 'U/M' then ROUND(L.UMShipped * price / L.per,2) else price end) as SCTotalInvoice
    FROM OrderLineServiceCharges OLSC inner join OrderLines L on OLSC.ob_OrderLines_RID = L.ID
--   left outer join Units U on U.ps_OrderLines_RID = L.ID
--   left outer join (select ob_Units_RID, sum(length * (qtyOnHand + isNull(qtyShipped,0))) as unitLFShipped 
--       from UnitLengths group by ob_Units_RID) as Z on U.ID = Z.ob_units_RID
    WHERE L.ob_Orders_RID = @orderID) as SC on 1 = 1    
    

where O.ID = @orderID and (@tripNumber = 0 OR @tripNumber = L.tripNumber)
    and (U.ID is not null 
    or @tripNumber = 0
    or (I.id > 10000 and I.ID < 10010))
    --and L.designStatus = 'W/P'

UNION

select OLSC.ID, L.lineNumber + row_number()  over (order by OLSC.ID) * 0.02, 1, case when OLSC.priceMode = 'U/M' then L.customerUM else '' end, price, 
    case when OLSC.priceMode = 'U/M' then L.perString else '' end, '', '', description,
    L.customerUM, per, L.UMShipped, '', '', 'SVC', null, 1, 1, 
    case when OLSC.priceMode = 'U/M' then ROUND(L.UMShipped * price / L.per,2) else price end,totalInvoice + SCTotalInvoice,
    null, null, ROUND(
    case when isNull(C.salesTaxPct,0) = 0 then 0 when O.pickup = 1 then @salesTaxPct else isNull(C.salesTaxPct,0) end 
    * (X.totalInvoice + isNull(SCTotalInvoice,0)) * 0.01,2), dbo.ServiceChargeDescripionFor1Line(L.ID) as serviceChargeDescription

FROM OrderLineServiceCharges OLSC inner join OrderLines L on OLSC.ob_OrderLines_RID = L.ID
inner join Orders O on O.ID = L.ob_Orders_RID
inner join Customers C on O.ob_Customers_RID = C.ID
--left outer join Units U on U.ps_OrderLines_RID = L.ID
--left outer join (select ob_Units_RID, sum(length * (qtyOnHand + isNull(qtyShipped,0))) as unitLFShipped 
--    from UnitLengths group by ob_Units_RID) as Z on U.ID = Z.ob_units_RID
    
    
left outer join (select sum(totalInvoice) as totalInvoice from (select 
    ROUND(case when L.ob_Items_RID > 10000 and L.ob_Items_RID < 10010 then 1 else 
--        ROUND(totLFShipped * 1.0 / I.LFperUM + 0.0001 ,0) end * L.actualPrice / L.per + 0.001,2) as totalInvoice
        ROUND(L.UMShipped,0) end * L.actualPrice / L.per + 0.001,2) as totalInvoice
    from Orders O inner join OrderLines L on O.ID = L.ob_Orders_RID
    inner join Items I on L.ob_items_RID = I.ID
--    left outer join (select U.ps_OrderLines_RID, 
--        sum(L.length * (L.qtyOnHand + L.qtyShipped)) as totLFShipped from Units U 
--        inner join UnitLengths L on L.ob_Units_RID = U.ID
--        group by U.ps_OrderLines_RID) as Z on L.ID = Z.ps_OrderLines_RID
     where L.ob_Orders_RID = @orderID) as X1) as X on 1 = 1

left outer join (select sum(
    case when OLSC.priceMode = 'U/M' then ROUND(L.UMShipped * price / L.per,2) else price end) as SCTotalInvoice
    FROM OrderLineServiceCharges OLSC inner join OrderLines L on OLSC.ob_OrderLines_RID = L.ID
--    left outer join Units U on U.ps_OrderLines_RID = L.ID
--    left outer join (select ob_Units_RID, sum(length * (qtyOnHand + isNull(qtyShipped,0))) as unitLFShipped 
--        from UnitLengths group by ob_Units_RID) as Z on U.ID = Z.ob_units_RID
    WHERE L.ob_Orders_RID = @orderID) as SC on 1 = 1        
    
    
    
    
WHERE L.ob_Orders_RID = @orderID and OLSC.price > 0 and L.designStatus = 'W/P'

order by L.ID,L.lineNumber
GO
