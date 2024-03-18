USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[JasperReportPaymentRegister]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[JasperReportPaymentRegister]


        @fromDate   date = '06/01/2019',
        @thruDate   date = '06/15/2019',
        @dateType   varchar(7) = 'Entry',
        @billTo     integer = 0

as

select P.ID, P.payment, P.credit, P.discount, P.undistributed, P.checkNumber, P.checkAmount,
R.name, R.city, B.bankCode, B.depositNumber, 
case when @dateType = 'Entry' then B.dateEntered else B.dateDeposit end as dateDeposit,  
L.payment as paymentLine , L.credit as creditLine, L.discount as discountLine, 
L.comments, I.invoiceNumberString as invoiceNumber,
I.dateEntered, I.discountDate, I.dueDate, I.invoiceDate, I.subTotal + I.salesTax as invoiceTotal, 
I.balance, C.name as customer

from PaymentHeader P inner join CustomerRelations R on P.ps_BillTo_RID = R.ID
inner join PaymentBatchHeader B on P.ob_PaymentBatchHeader_RID = B.ID

inner join  PaymentLines L on L.ob_PaymentHeader_RID = P.ID
inner join Invoices I on L.ob_Invoices_RID = I.ID
inner join Customers C on I.ob_Customer_RID = C.ID


where ((@dateType = 'Entry' and B.dateEntered between @fromDate and @thruDate)
    OR (@dateType = 'Entry' and B.dateEntered between @fromDate and @thruDate))
    
    AND (@billTo = 0 OR @billTo = R.ID)
order by 12, B.depositNumber, R.name, R.city, P.ID, I.invoiceNumberString
GO
