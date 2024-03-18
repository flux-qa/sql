USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[readPaymentAndDiscountAmount]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[readPaymentAndDiscountAmount]

@orderNumber integer = 402661,
@totalDiscount  decimal(10,2) output

as

select  @totalDiscount = T.discountPct
    from Orders O inner join CustomerRelations R on O.ob_BillTo_RID = R.ID
    inner join Terms T on R.whseTerms_RID = T.ID
    where O.OrderNumber = @orderNumber
GO
