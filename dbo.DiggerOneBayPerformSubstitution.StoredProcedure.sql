USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[DiggerOneBayPerformSubstitution]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DiggerOneBayPerformSubstitution]

@originalUnit  integer,
@newUnit       integer

-- last change 11/30/23

as


declare     @itemID         integer,
            @originalID     integer,
            @newID          integer,
            @LFperUM         float

            
select @itemID = ob_Items_RID, @originalID = ID from Units where unit = @originalUnit
select @LFperUM = LFperUM from Items where item = @itemID
select @newID = ID from Units where unit = @newUnit


-- INCREASE PIECE COUNT IN ORIGINAL UNITLENGTHS
update UnitLengths set qtyOnhand = qtyOnHand + pieces
from UnitLengths L inner join (select length, sum(take) as pieces, count(*) as noLengths
    from CADTransactionView 
    where sourceUnit = @originalUnit
    and designStatus = 'Des'
    group by length)  as Z on Z.length = L.length
where L.ob_Units_RID = @originalID

-- REDUCE PIECE COUNT IN NEW UNITLENGTGHS
update UnitLengths set qtyOnhand = qtyOnHand - pieces
from UnitLengths L inner join (select length, sum(take) as pieces, count(*) as noLengths
    from CADTransactionView 
    where sourceUnit = @originalUnit
    and designStatus = 'Des'
    group by length)  as Z on Z.length = L.length
where L.ob_Units_RID = @newID


-- INCREASE PIECE COUNT AND UM IN ORIGINAL UNIT AND SET INTACT FLAG
--select U.unit, ROUND(UMStock + totPieces * @LFperUM,0)
update Units set piecesStock = piecesStock + totPieces, UMStock = ROUND(UMStock + totLF / @LFperUM,0), unitType = 'I'
from Units U inner join (select sum(take) as totPieces, sum(length *  take) as totLF
    from CADTransactionView 
    where sourceUnit = @originalUnit
    and designStatus = 'Des')  as Z on 1 = 1
where U.ID = @originalID

-- REDUCE PIECE COUNT AND UM IN NEW UNIT AND CLEAR INTACT FLAG
--select U.unit, ROUND(UMStock + totPieces * @LFperUM,0)
update Units set piecesStock = piecesStock - totPieces, UMStock = ROUND(UMStock - totLF / @LFperUM,0), unitType = ''
from Units U inner join (select sum(take) as totPieces, sum(length * take) as totLF
    from CADTransactionView 
    where sourceUnit = @originalUnit
    and designStatus = 'Des')  as Z on 1 = 1
where U.ID = @newID

-- FINALLY UPDATE THE UnitLength.ID IN THE CADTransaction Table
Update CADTransactions set ps_UnitLengths_RID = UL.ID
    from CADTransactions CT inner join CADTransactionView T on CT.ID = T.TID
    inner join UnitLengths UL on UL.ob_Units_RID = @newID and T.length = UL.length
    where sourceUnit = @originalUnit
    and designStatus = 'Des'
GO
