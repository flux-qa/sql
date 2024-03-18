USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[JasperRebateCalculation]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[JasperRebateCalculation] 

-- last change 01/02/24


@fromDate date = '01/01/2023',
@thrudate date = '12/31/2023'

as

;

with w as (select  I.ob_BillTo_RID as billTo,
        ISNULL(sum(case when I.invoiceType = 'Invoice' then I.subTotal else 0 end),0) as totalWhse,
        isNULL(sum(case when I.invoiceType = 'Direct' then I.subTotal else 0 end),0) as totalDirects,
        ISNULL(sum(case when I.invoiceType = 'Credit Memo' then I.subTotal else 0 end),0) as totalCredits
        from Invoices I 
        where I.invoiceDate BETWEEN @fromDate and @thruDate
        group by I.ob_BillTo_RID),


x as (select I.ob_BillTo_RID as billTo, -1 * round(sum(P.credit),2) as paymentCredits
    from PaymentLines P inner join CreditCodes C on P.ps_CreditCode_RID = C.ID
    inner join Invoices I on P.ob_Invoices_RID = I.ID
    inner join PaymentHeader PH on P.ob_PaymentHeader_RID = PH.ID
    inner join PaymentBatchHeader B on PH.ob_PaymentBatchHeader_RID = B.ID
    where B.dateEntered  BETWEEN @fromDate and @thruDate
    and C.creditCode <> 'CC' and C.creditCode <> 'CA' and P.credit > 0
    group by I.ob_BillTo_RID) , 
    
z as (select R.name,  R.city, R.state, R.ID, RS.type, ISNULL(Z.RSDescription, '') as RSDescription,
    ISNULL(Z.itemTotal,W.totalWhse) + case when RS.includeDirects = 1 then W.totalDirects else 0 end + totalCredits + ISNULL(PaymentCredits,0) as netSales,
    RS.levelBreak1 as level1, RS.levelBreak2 as level2, 
    RS.pctBelowLevel1 as lowPct, RS.pctLevel1ThruLevel2 as midPct, RS.pctOverLevel2 as highPct,
    ISNULL(Z.itemTotal,W.totalWhse) as totalWhse, W.TotalDirects, W.totalCredits, X.paymentCredits, 
    RS.includeDirects, Z.itemTotal, Z.returnAmount
    from W left outer join X on W.billTo = X.billTo    
    inner join CustomerRelations R on W.billTo = R.ID
    inner join CustomerBillToRebateLink CBR on W.billTo = CBR.ps_BillTo_RID
    inner join RebateStructure RS on CBR.ob_RebateStructure_RID = RS.ID
    
        left outer join (select CBRL.ps_BillTo_RID as billTo, RS.ID as rebateStructureID, max(RS.description) as RSDescription,
            sum(round(L.UMShipped * L.actualPrice / L.per,2)) as itemTotal, sum(round(returnAmount, 2)) as returnAmount
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
            group by CBRL.ps_BillTo_RID, RS.ID) as Z on Z.billTo = R.ID
            and Z.rebateStructureID = RS.ID),    
                 

  w1 as (select  I.ob_Customer_RID as shipTo,
        ISNULL(sum(case when I.invoiceType = 'Invoice' then I.subTotal else 0 end),0) as totalWhse,
        isNULL(sum(case when I.invoiceType = 'Direct' then I.subTotal else 0 end),0) as totalDirects,
        ISNULL(sum(case when I.invoiceType = 'Credit Memo' then I.subTotal else 0 end),0) as totalCredits
        from Invoices I 
        where I.invoiceDate BETWEEN @fromDate and @thruDate
        group by I.ob_Customer_RID),
        
  x1 as (select I.ob_Customer_RID as shipTo, -1 * round(sum(P.credit),2) as paymentCredits
    from PaymentLines P inner join CreditCodes C on P.ps_CreditCode_RID = C.ID
    inner join Invoices I on P.ob_Invoices_RID = I.ID
    inner join PaymentHeader PH on P.ob_PaymentHeader_RID = PH.ID
    inner join PaymentBatchHeader B on PH.ob_PaymentBatchHeader_RID = B.ID
    where B.dateEntered BETWEEN @fromDate and @thruDate
    and C.creditCode <> 'CC' and C.creditCode <> 'CA' and P.credit > 0
    group by I.ob_Customer_RID) ,   
          
          
z1 as (select C.name,  C.city, C.state, C.ID, RS.type, 
    W1.totalWhse + case when RS.includeDirects = 1 then W1.totalDirects else 0 end + totalCredits + ISNULL(PaymentCredits,0) as netSales,
    RS.levelBreak1 as level1, RS.levelBreak2 as level2,
    RS.pctBelowLevel1 as lowPct, RS.pctLevel1ThruLevel2 as midPct, RS.pctOverLevel2 as highPct,
    W1.totalWhse, W1.TotalDirects, W1.totalCredits, X1.paymentCredits, RS.includeDirects
    from W1 left outer join X1 on W1.shipTo = X1.shipTo    
    inner join Customers C on W1.ShipTo = C.ID
    inner join CustomerBillToRebateLink CBR on W1.shipTo = CBR.ps_Customers_RID
    inner join RebateStructure RS on CBR.ob_RebateStructure_RID = RS.ID
),    
               

        
A as (select  CIA.associationID,
        ISNULL(sum(case when I.invoiceType = 'Invoice' then I.subTotal else 0 end),0) as totalWhse,
        isNULL(sum(case when I.invoiceType = 'Direct' then I.subTotal else 0 end),0) as totalDirects,
        ISNULL(sum(case when I.invoiceType = 'Credit Memo' then I.subTotal else 0 end),0) as totalCredits
        from Invoices I inner join CustomersInAssociations CIA on I.ob_Customer_RID = CIA.customerID 
        where I.invoiceDate BETWEEN @fromDate and @thruDate
        group by CIA.associationID),
 

A1 as (select CIA.associationID, -1 * round(sum(P.credit),2) as paymentCredits
    from PaymentLines P inner join CreditCodes C on P.ps_CreditCode_RID = C.ID
    inner join Invoices I on P.ob_Invoices_RID = I.ID
    inner join PaymentHeader PH on P.ob_PaymentHeader_RID = PH.ID
    inner join PaymentBatchHeader B on PH.ob_PaymentBatchHeader_RID = B.ID
    inner join CustomersInAssociations CIA on I.ob_Customer_RID = CIA.customerID
    where B.dateEntered BETWEEN @fromDate and @thruDate
    and C.creditCode <> 'CC' and C.creditCode <> 'CA' and P.credit > 0
    group by CIA.associationID),
    
z2 as (select R.name,  R.city, R.state, R.ID, RS.type, 
    A.totalWhse + case when RS.includeDirects = 1 then A.totalDirects else 0 end + totalCredits + ISNULL(PaymentCredits,0) as netSales,
    RS.levelBreak1 as level1, RS.levelBreak2 as level2, 
    RS.pctBelowLevel1 as lowPct, RS.pctLevel1ThruLevel2 as midPct, RS.pctOverLevel2 as highPct,
    A.totalWhse, A.TotalDirects, A.totalCredits, A1.paymentCredits, RS.includeDirects
    from A left outer join A1 on A1.associationID = A.associationID    
    inner join CustomerRelations R on A.associationID  = R.ID
    inner join CustomerBillToRebateLink CBR on A.associationID = CBR.ps_BillTo_RID
    inner join RebateStructure RS on CBR.ob_RebateStructure_RID = RS.ID    
)



select name,  city, state, ID, totalWhse, case when RSDescription = '' then totalDirects else 0 end as totalDirects, 
    case when RSDescription = '' then totalCredits else returnAmount end as totalCredits, 
    case when RSDescription = '' then ISNULL(paymentCredits,0) else 0 end as paymentCredits, 
    'Bill To ' + case when type = 'Retroactive' then 'Back to $1' else type end + ' ' + RSDescription as rebateType, netSales,
    ROUND(case when type = 'Retroactive' then 
        case when netSales < Z.level1 then round(netSales * lowPct, 0)
        when netSales >= level1 and netSales < level2 then round(netSales * midPct, 0)
        else round(netSales * highPct, 0) end 
    else 
        case when netsales < 0 then 0 when netSales < level1 then round(netSales * lowPct,0) else round(level1 * lowPct,0) end +
        case when netsales < level1 then 0 when netsales < level2 then round((netSales - level1) * midPct,0) else round((level2 - level1) * midPct,0) end +
        case when netsales < level2 then 0 else round((netsales - level2) * highPct,0) end         
        end * 0.01,2) as rebateAmount, level1, level2, lowpct, midpct, highpct
    from Z

UNION ALL
    
select name,  city, state, ID, totalWhse, totalDirects, totalCredits, 
    ISNULL(paymentCredits,0) as paymentCredits, 'Ship To ' + case when type = 'Retroactive' then 'Back to $1' else type end as rebateType, netSales,
    ROUND(case when type = 'Retroactive' then 
        case when netSales < level1 then round(netSales * lowPct, 0)
        when netSales >= level1 and netSales < level2 then round(netSales * midPct, 0)
        else round(netSales * highPct, 0) end 
    else 
        case when netsales < 0 then 0 when netSales < level1 then round(netSales * lowPct,0) else round(level1 * lowPct,0) end +
        case when netsales < level1 then 0 when netsales < level2 then round((netSales - level1) * midPct,0) else round((level2 - level1) * midPct,0) end +
        case when netsales < level2 then 0 else round((netsales - level2) * highPct,0) end         
        end * 0.01,2) as rebateAmount, level1, level2, lowpct, midpct, highpct
    from Z1

UNION ALL
    
select name,  ISNULL(city,'') as city, ISNULL(state,'') as state, ID, totalWhse, totalDirects, totalCredits, 
    ISNULL(paymentCredits,0) as paymentCredits, 'Assoc. ' + case when type = 'Retroactive' then 'Back to $1' else type end as rebateType, netSales,
    ROUND(case when type = 'Retroactive' then 
        case when netSales < level1 then round(netSales * lowPct, 0)
        when netSales >= level1 and netSales < level2 then round(netSales * midPct, 0)
        else round(netSales * highPct, 0) end 
    else 
        case when netsales < 0 then 0 when netSales < level1 then round(netSales * lowPct,0) else round(level1 * lowPct,0) end +
        case when netsales < level1 then 0 when netsales < level2 then round((netSales - level1) * midPct,0) else round((level2 - level1) * midPct,0) end +
        case when netsales < level2 then 0 else round((netsales - level2) * highPct,0) end         
        end * 0.01,2) as rebateAmount, level1, level2, lowpct, midpct, highpct
    from Z2
        
  
    
 
    
    
    order by name, city, ID
GO
