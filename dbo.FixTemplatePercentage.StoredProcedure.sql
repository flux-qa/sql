USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[FixTemplatePercentage]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[FixTemplatePercentage]
--
-- 12/10/15
--

@item integer,
@selectedlength integer


as
declare @noLengths integer,
        @pctDelta float,
        @lengthPct float
        
select @lengthPct = tempSuggestedPct from Templates where ob_Items_RID = @Item and length = @selectedLength

select @noLengths = count(*) - 1, @pctDelta = 100 - sum(tempSuggestedPct)
    from TEMPLATES where ob_Items_RID = @Item and tempSuggestedPct > 0

if @NoLengths > 0  AND @pctDelta + @lengthPct <> 100 begin

    update TEMPLATES
        set tempSuggestedPct = tempSuggestedPct + Round(@pctDelta / (100.0 - (@pctDelta + @lengthPct))  * tempSuggestedPct ,1)
        where ob_Items_RID = @Item and length <> @SelectedLength and tempSuggestedPct > 0

    
    update TEMPLATES
        set tempSuggestedPCT = 0
        where ob_Items_RID = @Item and tempSuggestedPCT < 0
end
GO
