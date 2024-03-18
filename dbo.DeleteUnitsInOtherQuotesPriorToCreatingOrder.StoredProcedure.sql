USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[DeleteUnitsInOtherQuotesPriorToCreatingOrder]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create procedure [dbo].[DeleteUnitsInOtherQuotesPriorToCreatingOrder]

@quoteID integer = 1002571

as

delete from quoteUnits where ID in  (
    select Q1.ID from quoteUnits Q1 inner join QuoteUnits Q2 on Q1.ps_Units_RID = Q2.ps_Units_RID
    where Q2.ob_Quotes_RID = @quoteID and Q1.ob_Quotes_RID <> @quoteID)
GO
