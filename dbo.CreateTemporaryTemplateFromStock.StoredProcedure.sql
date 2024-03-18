USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateTemporaryTemplateFromStock]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create Procedure [dbo].[CreateTemporaryTemplateFromStock]
@itemID integer

as

declare @grandTotalLF integer

select @grandTotalLF =  sum(L.length * qtyOnHand)
    from  UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
    where U.ob_Items_RID = @itemID 
    and L.qtyOnHand > 0 and U.pocketWoodFlag = 0

update Templates set tempSuggestedPct = null where ob_Items_RID = @itemID

IF @grandTotalLF > 0
    Update Templates set tempSuggestedPct = ROUND(100.0 * lengthLF / @grandTotalLF,1)
    from Templates T inner join (select length, sum(L.length * qtyOnHand) as lengthLF
        from UnitLengths L
        inner join Units U on L.ob_Units_RID = U.ID
        where U.ob_Items_RID = @itemID 
        and L.qtyOnHand > 0 and U.pocketWoodFlag = 0
        group by L.length) as Z on T.length = Z.length
        where T.ob_Items_RID = @itemID
GO
