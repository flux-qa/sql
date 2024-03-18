USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[InvoicesAndPayments]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[InvoicesAndPayments]

    @fromDate	date = '01/01/2023',
    @thruDate	date = '03/01/2023'

as

SELECT C.name, C.city, I.invoiceNumber, cast(I.subTotal as integer) as amount, cast(I.invoiceDate as date) as Invdate, cast(P.depositDate as date) as depositDate
from Invoices I inner join Customers C on I.ob_Customer_RID = C.ID
                left outer join (select P.ob_Invoices_RID, min(PBH.dateDeposit) as depositDate
                                 from PaymentLines P inner join PaymentHeader PH on P.ob_PaymentHeader_RID = PH.ID
                                                     inner join PaymentBatchHeader PBH on PH.ob_PaymentBatchHeader_RID = PBH.ID
                                 group by P.ob_Invoices_RID) as P on P.ob_Invoices_RID = I.ID
where I.invoiceDate between @fromDate and @thruDate
order by C.name, C.city, I.invoiceNumber
GO
