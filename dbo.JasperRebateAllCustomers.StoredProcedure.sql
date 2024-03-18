USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[JasperRebateAllCustomers]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[JasperRebateAllCustomers]

-- last change 12/28/23

@fromDate date = '01/01/2023',
@thrudate date = '12/31/2023'

AS

;


with w as (select  I.ob_BillTo_RID as billTo,
        ISNULL(sum(case when I.invoiceType = 'Invoice' then I.subTotal else 0 end),0) as totalWhse,
        isNULL(sum(case when I.invoiceType = 'Direct' then I.subTotal else 0 end),0) as totalDirects,
        ISNULL(sum(case when I.invoiceType = 'Credit Memo' then I.subTotal else 0 end),0) as totalCredits
        from Invoices I 
        where I.invoiceDate BETWEEN @fromDate and @thruDate
        group by I.ob_BillTo_RID),


x as (select I.ob_BillTo_RID, round(sum(P.credit),2) as payCreditAmount
    from PaymentLines P inner join CreditCodes C on P.ps_CreditCode_RID = C.ID
    inner join Invoices I on P.ob_Invoices_RID = I.ID
    inner join PaymentHeader PH on P.ob_PaymentHeader_RID = PH.ID
    inner join PaymentBatchHeader B on PH.ob_PaymentBatchHeader_RID = B.ID
    where B.dateEntered  BETWEEN @fromDate and @thruDate
    and C.creditCode <> 'CC'
    group by I.ob_BillTo_RID) , 
          

y as (select CBR.ps_BillTo_RID as billTo, R.type, R.levelBreak1, R.pctBelowLevel1, 
        R.levelBreak2, R.pctLevel1ThruLevel2, R.pctOverLevel2,
        0.01 * sum(case when (iSNULL(ZZ.itemTotal,W.totalWhse) - (W.totalCredits + ISNULL(X.payCreditAmount,0))) <= R.levelBreak1 then R.pctBelowLevel1
        when (iSNULL(ZZ.itemTotal,W.totalWhse) - (W.totalCredits + ISNULL(X.payCreditAmount,0))) <= R.levelBreak2 then R.pctLevel1ThruLevel2
        when (iSNULL(ZZ.itemTotal,W.totalWhse) - (W.totalCredits + ISNULL(X.payCreditAmount,0))) >  R.levelBreak2 then R.pctOverLevel2
        else 0 end) as rebatePct, 
        sum( case when includeDirects = 1 then 1 else 0 end) as includeDirects,
        max(ZZ.itemTotal) as itemTotal, max(ZZ.returnAmount) as returnAmount
        from CustomerBillToRebateLink CBR inner join RebateStructure R on CBR.ob_RebateStructure_RID = R.ID
        inner join W on W.billTo = CBR.ps_BillTo_RID
        left outer join X on X.ob_Billto_RID = W.billTo
        
        left outer join (select CBRL.ps_BillTo_RID as billTo, RS.ID as rebateStructureID,
            sum(round(L.UMShipped * L.actualPrice / L.per,2)) as itemTotal,
            sum(round(returnAmount, 2)) as returnAmount
            from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
            inner join Customers C on C.ID = O.originalShipTo_RID
            inner join Items I on L.ob_Items_RID = I.ID
            inner join ItemGroupings_REF IGR on IGR.RID = I.ID
            inner join ItemGroupings IG on IGR.ID = IG.ID
            inner join RebateStructure RS on RS.ps_ItemGroupings_RID = IG.ID
            inner join CustomerBillToRebateLink CBRL on CBRL.ob_RebateStructure_RID = RS.ID and CBRL.ps_BillTo_RID = O.ob_BillTo_RID
                left outer join (select ob_OrderLines_RID, sum(isnull(creditAmount,0)) as returnAmount from returns group by ob_OrderLines_RID) as RET
                    on RET.ob_OrderLines_RID = L.ID              
            where L.dateShipped between @fromDate and @thruDate
            group by CBRL.ps_BillTo_RID, RS.ID) as ZZ on ZZ.billTo = CBR.ps_BillTo_RID and ZZ.rebateStructureID = R.ID
            
        group by CBR.ps_BillTo_RID, R.type, R.levelBreak1, R.pctBelowLevel1, R.levelBreak2, 
        R.pctLevel1ThruLevel2, R.pctOverLevel2),
        

  w1 as (select  I.ob_Customer_RID as shipTo,
        ISNULL(sum(case when I.invoiceType = 'Invoice' then I.subTotal else 0 end),0) as totalWhse,
        isNULL(sum(case when I.invoiceType = 'Direct' then I.subTotal else 0 end),0) as totalDirects,
        ISNULL(sum(case when I.invoiceType = 'Credit Memo' then I.subTotal else 0 end),0) as totalCredits
        from Invoices I 
        where I.invoiceDate BETWEEN @fromDate and @thruDate
        group by I.ob_Customer_RID),
        
  x1 as (select I.ob_Customer_RID, round(sum(P.credit),2) as payCreditAmount
    from PaymentLines P inner join CreditCodes C on P.ps_CreditCode_RID = C.ID
    inner join Invoices I on P.ob_Invoices_RID = I.ID
    inner join PaymentHeader PH on P.ob_PaymentHeader_RID = PH.ID
    inner join PaymentBatchHeader B on PH.ob_PaymentBatchHeader_RID = B.ID
    where B.dateEntered BETWEEN @fromDate and @thruDate
    and C.creditCode <> 'CC'
    group by I.ob_Customer_RID) ,         
        
y1 as (select CBR.ps_Customers_RID as shipTo, R.type, R.levelBreak1, R.pctBelowLevel1, R.levelBreak2, R.pctLevel1ThruLevel2, R.pctOverLevel2,
        0.01 * sum(case when (W1.totalWhse - (W1.totalCredits + ISNULL(X1.payCreditAmount,0))) <= R.levelBreak1 then R.pctBelowLevel1
        when (W1.totalWhse - (W1.totalCredits + ISNULL(X1.payCreditAmount,0))) <= R.levelBreak2 then R.pctLevel1ThruLevel2
        when (W1.totalWhse - (W1.totalCredits + ISNULL(X1.payCreditAmount,0))) >  R.levelBreak2 then R.pctOverLevel2
        else 0 end) as rebatePct, sum( case when includeDirects = 1 then 1 else 0 end) as includeDirects
        from CustomerBillToRebateLink CBR inner join RebateStructure R on CBR.ob_RebateStructure_RID = R.ID
        inner join W1 on W1.shipTo = CBR.ps_Customers_RID
        left outer join X1 on X1.ob_Customer_RID = W1.shipTo
        group by CBR.ps_Customers_RID, R.type, R.levelBreak1, R.pctBelowLevel1, R.levelBreak2, R.pctLevel1ThruLevel2, R.pctOverLevel2),
        
        
A as (select  CIA.associationID,
        ISNULL(sum(case when I.invoiceType = 'Invoice' then I.subTotal else 0 end),0) as totalWhse,
        isNULL(sum(case when I.invoiceType = 'Direct' then I.subTotal else 0 end),0) as totalDirects,
        ISNULL(sum(case when I.invoiceType = 'Credit Memo' then I.subTotal else 0 end),0) as totalCredits
        from Invoices I inner join CustomersInAssociations CIA on I.ob_Customer_RID = CIA.customerID 
        where I.invoiceDate BETWEEN @fromDate and @thruDate
        group by CIA.associationID),
 

A1 as (select CIA.associationID, round(sum(P.credit),2) as payCreditAmount
    from PaymentLines P inner join CreditCodes C on P.ps_CreditCode_RID = C.ID
    inner join Invoices I on P.ob_Invoices_RID = I.ID
    inner join PaymentHeader PH on P.ob_PaymentHeader_RID = PH.ID
    inner join PaymentBatchHeader B on PH.ob_PaymentBatchHeader_RID = B.ID
    inner join CustomersInAssociations CIA on I.ob_Customer_RID = CIA.customerID
    where B.dateEntered BETWEEN @fromDate and @thruDate
    and C.creditCode <> 'CC'
    group by CIA.associationID),  
                    
A2 as (select  A.associationID , R.type, R.levelBreak1, R.pctBelowLevel1, R.levelBreak2, R.pctLevel1ThruLevel2, R.pctOverLevel2,
        0.01 * sum(case when (A.totalWhse - (A.totalCredits + ISNULL(A1.payCreditAmount,0))) <= R.levelBreak1 then R.pctBelowLevel1
        when (A.totalWhse - (A.totalCredits + ISNULL(A1.payCreditAmount,0))) <= R.levelBreak2 then R.pctLevel1ThruLevel2
        when (A.totalWhse - (A.totalCredits + ISNULL(A1.payCreditAmount,0))) >  R.levelBreak2 then R.pctOverLevel2
        else 0 end) as rebatePct, sum( case when includeDirects = 1 then 1 else 0 end) as includeDirects
        from CustomerBillToRebateLink CBR inner join RebateStructure R on CBR.ob_RebateStructure_RID = R.ID
        inner join A on A.associationID = CBR.ps_BillTo_RID
        left outer join A1 on A1.associationID = A.associationID
        group by A.associationID, R.type, R.levelBreak1, R.pctBelowLevel1, R.levelBreak2, R.pctLevel1ThruLevel2, R.pctOverLevel2)
        

select R.name, I.invoiceNumber, I.invoiceDate, R.city, R.state, R.ID,
    case when I.invoiceType = 'Invoice' then I.subTotal else 0 end as Warehouse,
    case when I.invoiceType = 'Direct' then I.subTotal else 0 end as Directs,
    case when I.invoiceType = 'Credit Memo' then I.subTotal else 0 end as Credits,
    ISNULL(Y.itemTotal, W.totalWhse) as totalWhse,  W.totalDirects,  W.totalCredits, Y.rebatePct, Y.includeDirects,
    type, levelBreak1, pctBelowLevel1, levelBreak2, pctLevel1ThruLevel2, pctOverLevel2

    from Invoices I inner join CustomerRelations R on I.ob_BillTo_RID = R.ID
    inner join Y on Y.billTo = I.ob_BillTo_RID
    inner join W on W.billTo = I.ob_BillTo_RID
    where I.invoiceDate BETWEEN  @fromDate and @thruDate
    
   UNION ALL
   
   select C.name, I.invoiceNumber, I.invoiceDate, C.city, C.state, C.ID,
    case when I.invoiceType = 'Invoice' then I.subTotal else 0 end as Warehouse,
    case when I.invoiceType = 'Direct' then I.subTotal else 0 end as Directs,
    case when I.invoiceType = 'Credit Memo' then I.subTotal else 0 end as Credits,
    W1.totalWhse,  W1.totalDirects,  W1.totalCredits, Y1.rebatePct, Y1.includeDirects,
    type, levelBreak1, pctBelowLevel1, levelBreak2, pctLevel1ThruLevel2, pctOverLevel2

    from Invoices I inner join Customers C on I.ob_Customer_RID = C.ID
    inner join Y1 on Y1.shipTo = I.ob_Customer_RID
    inner join W1 on W1.shipTo = I.ob_Customer_RID
    where I.invoiceDate BETWEEN  @fromDate and @thruDate
    
    UNION ALL
    
    
select R.name, I.invoiceNumber, I.invoiceDate, ISNULL(R.city,'') as city, ISNULL(R.state,'') as state, R.ID,
    case when I.invoiceType = 'Invoice' then I.subTotal else 0 end as Warehouse,
    case when I.invoiceType = 'Direct' then I.subTotal else 0 end as Directs,
    case when I.invoiceType = 'Credit Memo' then I.subTotal else 0 end as Credits,
    A.totalWhse,  A.totalDirects,  A.totalCredits, A2.rebatePct, A2.includeDirects,
    type, levelBreak1, pctBelowLevel1, levelBreak2, pctLevel1ThruLevel2, pctOverLevel2

    from Invoices I inner join CustomersInAssociations CIA on I.ob_Customer_RID = CIA.customerID 
    inner join CustomerRelations R on CIA.associationID = R.ID
    inner join A2 on A2.associationID = CIA.associationID
    inner join A on A.associationID = CIA.associationID
    where I.invoiceDate BETWEEN  @fromDate and @thruDate
    
    
    order by name, city, ID, invoiceDate, invoiceNumber
GO
