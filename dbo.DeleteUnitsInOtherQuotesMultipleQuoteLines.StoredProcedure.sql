USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[DeleteUnitsInOtherQuotesMultipleQuoteLines]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DeleteUnitsInOtherQuotesMultipleQuoteLines]

@custno integer = 7669

as

delete from quoteUnits where id in (select Q2.ID from quoteUnits Q1 inner join Quotes Q on Q1.ob_Quotes_RID = Q.ID 
    inner join QuoteUnits Q2 on Q1.ps_Units_RID = Q2.ps_Units_RID AND Q1.ob_Quotes_RID <> Q2.ob_Quotes_RID 
    where Q.ob_Customers_RID = @custno and Q.selectedFlag = 1)
GO
