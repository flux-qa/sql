USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReturnWholeUnitsUMStockAssignedToQuote]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReturnWholeUnitsUMStockAssignedToQuote]

@quoteID integer = 1702335,
@wholeUnitsUMStock integer OUT
as


select @wholeUnitsUMStock = ROUND(isNull(sum(UMStock + UMRolling),0),0)
from Units U inner join QuoteUnits QU on U.ID = QU.ps_Units_RID
where QU.ob_Quotes_RID = @quoteID
GO
