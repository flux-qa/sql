USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadPaymentSummaryOneBillTo]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadPaymentSummaryOneBillTo]
@billToID integer

as

select row_number() over (order by P.ID) as ID, 1 as BASVERSION, getdate() as BASTIMESTAMP,
B.dateDeposit as depositDate, P.checkNumber, P.checkAmount


from PaymentHeader P inner join PaymentBatchHeader B on P.ob_PaymentBatchHeader_RID = B.ID
where P.ps_BillTo_RID = @billToID and
dateAdd(yy, -1, getdate()) < B.dateDeposit 
order by B.dateDeposit desc
GO
