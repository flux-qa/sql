USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateQuoteCustomTallyString]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateQuoteCustomTallyString]
@quoteID integer,
@customTallyString  char(200) output

as

select @customTallyString = dbo.QuoteCustomTallyToString(@quoteID)
GO
