USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CheckUnitForAvailableLengths]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CheckUnitForAvailableLengths] 

@item integer,
@unit integer ,
@noLengths  integer out

as

with w as (select L.length, sum(qtyOnHand) - max(isNull(allocated,0)) as available, max(isNull(Y.qtyStock,0)) as qtyStock
    from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
        left outer join (select length, sum(pieces) as allocated
        from OrderTally T inner join OrderLines L on T.ob_OrderLines_RID = L.ID
        where L.ob_Items_RID = @Item and L.UMShipped = 0 and L.wrd = 'W' 
        group by T.length) as Z on L.length = Z.length
        inner join (select length, sum(qtyOnHand) as qtyStock
        from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
        where U.unit = @unit   
        group by L.length) as Y on L.length = Y.length   
    
    where U.ob_Items_RID = @item and U.pocketWoodFlag = 0
    and qtyOnHand > 0 
    group by L.length)
    
select @noLengths = count(*) from w where qtyStock > available
--select @noLengths = 0
GO
