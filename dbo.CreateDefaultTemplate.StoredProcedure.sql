USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateDefaultTemplate]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateDefaultTemplate]
--
-- 12/22/15
-- 01/21/16 -- fixed stock pct was 100 times too large
-- 01/22/16 -- added growth columns
-- 03/10/16 -- removed pocketwood from calc
--
@Item integer

as 

--declare   @NextID integer

--delete from Templates where ob_Items_RID = @Item

    BEGIN TRANSACTION
--    select @NextID = max(ID) from Templates
;

    with w as (select ID, sum(totalLF) as itemTotal 
        from ItemLengthsStockPlusShipped2Years where ID = @Item group by ID)


    INSERT INTO [dbo].[Templates]([ID], [BASVERSION], [BASTIMESTAMP], 
        [ob_Items_REN], [ob_Items_RID], [ob_Items_RMA], 
        [length], [suggestedPct]) 


    select next Value for BAS_IDGEN_SEQ, 1, getDate(),
        'Items', I.ID, null , I.length, round(1000.0  * totalLF / itemTotal,0) / 10 as suggestedPct
        from ItemLengthsStockPlusShipped2Years I inner join W on I.ID = W.ID
        where itemTotal > 0 and I.length not in (select Length from Templates where ob_Items_RID = @Item)   

   

    COMMIT TRANSACTION
    
    
    update Templates set UMStock = ISNULL(UMTemplate,0) , pctStock = isNULL(pctTemplatable,0),
        pctShort = null, UMShortWithGrowth = case when isNULL(pctTemplatable,0) * 100  >= suggestedPct then null
        else ROUND((0.01 * suggestedPct - isNULL(pctTemplatable,0)) * Z.totAvail,0) end
        from Templates T left outer join (
            select I.ID, L.length, sum(L.qtyOnHand) as pcs,
                ROUND(sum(L.length * L.qtyOnHand * I.LFperUM),0) as UMTemplate,
                ROUND(100.0 * sum(L.length * L.qtyOnHand / I.LFperUM) /
                max((I.UMStock - I.UMPocketWood)),0)  * 0.01 as pctTemplatable,
                 max(I.UMStock - I.UMPocketwood) as totAvail
                from Units U inner join UnitLengths L on U.ID = L.ob_Units_RID
                inner join Items I on I.ID = U.ob_Items_RID
                where  U.ob_Items_RID = @ITEM and I.LFperUM > 0 and
                L.qtyOnHand <> 0 and U.pocketWoodFlag = 0 and I.UMStock > 0 and I.LFperUM > 0
                group by I.ID, L.length) as Z on T.ob_Items_RID = Z.ID and T.length = Z.length
        WHERE T.ob_Items_RID = @Item 
    

        update templates set pctShort = 
            case when pctStock = 0 OR pctStock * 100 >= suggestedPct then 0 else round(10000.0 *  pctStock / suggestedPct, 2) end
            where ob_Items_RID = @ITEM and (suggestedPct > 0 and suggestedPct IS NOT NULL)
            

        update Templates set suggestedPct = 100.0 where ob_items_RID = @item and suggestedPct > 99
GO
