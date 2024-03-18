USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[JasperPaymentAnalysisToFile]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[JasperPaymentAnalysisToFile]
as  

delete from PaymentAnalysis
;

with w as (select ps_BillTo_RID as billTo, max(PB.dateDeposit) as lastPayment
    from PaymentHeader P inner join PaymentBatchHeader PB on P.ob_PaymentBatchHeader_RID = PB.ID
    where PB.dateDeposit >= dateAdd(yy, -1, getdate())
    group by ps_BillTo_RID),
    
    x as (select I.ob_BillTo_RID as billTo, 
    sum(case when I.discountDate >= dateadd(dd,-5, PB.dateDeposit) and PL.discount > 0 then 1 else 0 end) as tookDiscount,
    sum(case when I.discountDate < dateadd(dd,-5, PB.dateDeposit) and PL.discount > 0 then 1 else 0 end) as tookLateDiscount,
    sum(case when I.discountDate < dateadd(dd,-5, PB.dateDeposit) and PL.discount > 0 then 
        datediff(dd, I.discountDate, dateAdd(dd, -5, PB.dateDeposit)) else 0 end) as totLateDiscount,   
    sum(case when I.dueDate >= dateAdd(dd,-5, PB.dateDeposit)  then 1 else 0 end) as paidOnTime,
    sum(case when I.dueDate < dateAdd(dd,-5, PB.dateDeposit) then 1 else 0 end) as paidLate,
    sum(case when I.dueDate < dateAdd(dd,-5, PB.dateDeposit) then I.subTotal else 0 end) as paidLateWeighted,
    sum(case when PB.dateDeposit IS NOT NULL then I.subTotal else 0 end) as avgDivisor,
    sum(case when PB.dateDeposit IS NOT NULL then datediff(dd, I.invoiceDate, PB.dateDeposit) * I.subTotal else 0 end) as avgNumerator,
    
    max(case when I.dueDate < dateAdd(dd,-5, PB.dateDeposit) then datediff(dd, I.dueDate, dateAdd(dd, -5, PB.dateDeposit)) else 0 end) as maxDaysLate,
    sum(case when I.dueDate < dateAdd(dd,-5, PB.dateDeposit) then datediff(dd, I.dueDate, dateAdd(dd, -5, PB.dateDeposit)) else 0 end) as totDaysLate,
    sum(case when I.dueDate < dateAdd(dd,-5, PB.dateDeposit) then datediff(dd, I.dueDate, dateAdd(dd, -5, PB.dateDeposit)) * I.subTotal else 0 end) as totDaysLateWeighted
    from PaymentHeader P inner join PaymentBatchHeader PB on P.ob_PaymentBatchHeader_RID = PB.ID    
    inner join PaymentLines PL on PL.ob_PaymentHeader_RID = P.ID
    inner join Invoices I on PL.ob_Invoices_RID = I.ID
    left outer join creditCodes CC on PL.ps_CreditCode_RID = CC.ID
    where PB.dateDeposit >= dateadd(yy, -1, getdate()) and I.subTotal > 0 and (CC.creditCode is null or (CC.creditCode <> 'CC' and CC.creditCode <> 'CA'))
    group by I.ob_BillTo_RID)

/*
select R.name, R.city, Z.nowLate, Z.numbNowLate, Z.lastPayment, Z.tookDiscount, Z.tookLateDiscount, 
    case when Z.tookLateDiscount = 0 then 0 else round(Z.totLateDiscount / Z.tookLateDiscount,0) end as avgLateDiscDays,
    Z.paidOnTime, Z.paidLate, Z.maxLate,
    case when Z.paidLate = 0 then 0 else round(Z.totDaysLate / Z.paidLate,0) end as avgLate,
    case when Z.paidLateWeighted = 0 then 0 else round(Z.totDaysLateWeighted / Z.paidLateWeighted,0) end as avgLateWeighted,
    case when Z.avgDivisor > 0 then round(Z.avgNumerator / Z.avgDivisor,0) else 0 end as avgDaysToPay
*/

INSERT INTO PaymentAnalysis (ID, BASVERSION, BASTIMESTAMP,
    name, city, nowLate, avgDaysToPay, 
    paidLateNoPct, avgLateWeighted,  tookLateDiscountNoPct,
    avgLateDiscDays, noOpenInvoices)



select row_number() over (order by R.name) as ID, 1 as BASVERSION, getdate() as BASTIMESTAMP,
    R.name, R.city, z.NowLate,     
    case when Z.avgDivisor > 0 then round(Z.avgNumerator / Z.avgDivisor,0) else 0 end as avgDaysToPay,

    case when Z.paidOnTime + Z.paidLate + Z.numbNowLate = 0 then 0 else round(100.0 * z.paidLate /(Z.paidOnTime + Z.paidLate + Z.numbNowLate),2) end as paidLateNoPct,
    case when Z.paidLateWeighted = 0 then 0 else round(Z.totDaysLateWeighted / Z.paidLateWeighted,0) end as avgLateWeighted,

    case when Z.paidLate + Z.paidOnTime = 0 then 0 else round(100.0 * Z.tookLateDiscount / (Z.paidLate + Z.paidOnTime),2) end as tookLateDiscountNoPct,    
    case when Z.tookLateDiscount = 0 then 0 else round(Z.totLateDiscount / Z.tookLateDiscount,0) end as avgLateDiscDays, 
    noOpenInvoices + Z.paidOnTime + Z.paidLate as noOpenInvoices    
    
    from CustomerRelations R inner join (
        select I.ob_BillTo_RID as billTo,  sum(case when I.dueDate < getDate() then I.balance else 0 end) as nowLate,
            sum(case when I.balance > 0 AND I.dueDate < getdate() then 1 else 0 end) as numbNowLate,
            count(*) as noOpenInvoices,
            cast(max(w.lastPayment) as date) as lastPayment, 
            max(tookDiscount) as tookDiscount, max(tookLateDiscount) as tookLateDiscount, max(paidOnTime) as paidOnTime,
            max(paidLate) as paidLate, max(maxDaysLate) as maxLate, max(totDaysLate) as totDaysLate, max(totLateDiscount) as totLateDiscount, 
            max(paidLateWeighted) as paidLateWeighted, max(totDaysLateWeighted) as totDaysLateWeighted,
            max(avgDivisor) as avgDivisor, max(avgNumerator) as avgNumerator
            from Invoices I 
            left outer join W on W.billTo= I.ob_BillTo_RID
            left outer join X on X.billTo = I.ob_BillTo_RID
            where I.balance > 0
            
            group by I.ob_BillTo_RID
            having sum(I.balance) > 0 or max(w.lastPayment) <> null) as Z on R.ID = Z.billTo
    order by R.name, R.city
GO
