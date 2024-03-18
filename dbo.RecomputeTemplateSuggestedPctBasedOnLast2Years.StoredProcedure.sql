USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[RecomputeTemplateSuggestedPctBasedOnLast2Years]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[RecomputeTemplateSuggestedPctBasedOnLast2Years]
@item integer = 0

-- last change 05/23/18
as


with w as (select ID, sum(totalLF) as itemTotal
 from ItemLengthsStockPlusShipped2Years 
 where @item = 0 OR ID = @item
 group by ID
 )
 

update Templates set suggestedPCT = round(100.0  * totalLF / itemTotal,1)
    from Templates T inner join ItemLengthsStockPlusShipped2Years I on T.ob_Items_RID = I.ID and T.length = I.length
    inner join W on I.ID = W.ID
    where (@item = 0 OR T.ob_Items_RID = @Item) and itemTotal > 0
GO
