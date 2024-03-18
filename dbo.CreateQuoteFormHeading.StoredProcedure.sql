USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateQuoteFormHeading]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[CreateQuoteFormHeading]

--@QuoteID integer,
@ItemID integer,
@formHeading varchar(400) OUTPUT
as 


with w as (select ob_Items_RID as item, round(min(UMStock),0) as smallestUnit, 
    round(max(UMStock),0) as largestUnit, round(avg(UMStock),0) as avgUnit,
    count(*) as noUnits

    from UNITS
    where ob_Items_RID = @itemID and UMStock > 0 and ps_OrderLines_RID is null
    group by ob_Items_RID)


    select @formHeading = case when UMStock <= 0 and UMOpenPO <= 0 then 
    internalDescription + '<br> ** NO STOCK!  NO POS &nbsp; &nbsp; CAN NOT SELL **'

    when UMStock <= 0 then
    internalDescription + '<br> ** NO STOCK! Can Sell from On Order Only! <b>' + 
        Format(UMOpenPO, '#,##0') + '</b> ' + I.UM + ' On Order'

    else internalDescription + '<br><b>' + Format(UMAvailable, '#,##0') 
        + '</b> ' + I.UM + case when UMOpenPO > 0 then ' &nbsp; &nbsp; &nbsp;<b>' + 
        Format(UMOpenPO, '#,##0') + '</b> ' + I.UM + ' On Order' else '' end

/*
' &nbsp; &nbsp; &nbsp; <b>' + format(noUnits, '#,##0') + 
        '</b> Units  &nbsp;  (<b>' + format(smallestUnit, '#,##0') + 
        '</b> - <b>' + format(largestUnit, '#,##0') + '</b>) &nbsp; <b>' + 
        format(avgUnit, '#,##0') + '</b> avg.'
*/
    end

    from ITEMS I left outer join W on I.ID = W.item
    where I.ID = @itemID

--update QUOTES set formHeading = @formHeading where ID = @QuoteID
GO
