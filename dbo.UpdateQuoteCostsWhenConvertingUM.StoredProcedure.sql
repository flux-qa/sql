USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateQuoteCostsWhenConvertingUM]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateQuoteCostsWhenConvertingUM]
@QuoteID             integer,

@tallyUM            float,
@projectedCost      float,
@materialCost       float,
@handlingCost       float,
@freightCost        float,
@financeCost        float,
@sellingCost        float,
@suggestedPrice     float,
@customerQty        integer,
@customerUM         varchar(4),
@actualPrice        float,
@LFperUM            float,
@per                integer

AS

update Quotes set
    tallyUM         = @tallyUM,
    projectedCost   = @projectedCost,
    materialCost    = @materialCost,
    handlingCost    = @handlingCost,
    freightCost     = @freightCost,
    financeCost     = @financeCost,
    sellingCost     = @sellingCost,
    suggestedPrice  = @suggestedPrice,
    customerQty     = @customerQty,
    customerUM      = LTRIM(RTRIM(@customerUM)),
    actualPrice     = @actualPrice,
    LFperUM         = @LFperUM,
    per             = @per
    
    WHERE Quotes.ID = @QuoteID
GO
