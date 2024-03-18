USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ProcessMobileHandleTransactions]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ProcessMobileHandleTransactions]

-- last change 03/04/24

    @handleTargetLengthID   integer = 11627961,
    @took                   integer = 17,
    @tookAll                integer = 1,
    @piecesNested           integer = 0,
    @balance                integer = 0

as
    
     
declare
    @CADTransactionID       integer,
    @sourceUnitID           integer,
    @sourceUnitLengthID     integer,
    @targetUnitID           integer,
    @length                 integer,
    @take                   integer,
    @takeAll                integer

    
-- READ ALL OF THE PRIMARY KEYS TO TABLES NEEDED    
select @CADTransactionID = T.ID,
    @sourceUnitID = UL.ob_Units_RID,
    @sourceUnitLengthID = UL.ID,
    @targetUnitID = T.ps_TargetUnit_RID,
    @length = UL.length,
    @take = T.take,
    @takeAll = T.takeAll
    
    from HandleTargetLengths HL inner join UnitLengths UL on HL.ps_SourceUnit_RID = UL.ob_Units_RID and HL.length = UL.length
    inner join HandleTargetMobile HM on HL.ob_HandleTargetMobile_RID = HM.ID
    inner join CADTransactions T on T.ps_UnitLengths_RID = UL.ID and T.ps_CADDrills_RID = HL.ps_CADDrills_RID and T.ps_TargetUnit_RID = HM.ps_TargetUnit_RID
    
    where HL.ID = @handleTargetLengthID

-- UPDATE THE TOOK and TOOK ALL IN THE CAD TRANSACTIONS AND IN THE HandleTargetLengths
Update CADTransactions set took = @took, tookAll = @tookAll where ID = @CADTransactionID
Update HandleTargetLengths set took = @took, tookAll = @tookAll, piecesNested = @piecesNested, balance = @balance where ID = @handleTargetLengthID

-- IF TAKE <> TOOK THEN REDUCE THE PIECES IN THE SOURCE LENGTH AND SOURCE UNIT BY TOOK - TAKE
-- AND INCREASE THE PIECES IN THE TARGET AND TARGET LENGTH BY TOOK - TAKE
IF @take <> @took BEGIN
    Update UnitLengths set qtyOnHand = case when (@took - @take) >= qtyOnHand then 0 else qtyOnHand - (@took - @take) end where ID = @sourceUnitLengthID
    Update Units set piecesStock = case when (@took - @take) >= piecesStock then 0 else piecesStock - (@took - @take) end where ID = @sourceUnitID
    
    Update UnitLengths set qtyOnHand = case when (@took - @take) <= qtyOnHand then 0 else qtyOnHand + (@took - @take) end where ob_Units_RID = @targetUnitID and length = @length
    Update Units set piecesStock = case when (@took - @take) <= piecesStock then 0 else piecesStock + (@took - @take) end where ID = @targetUnitID
    END
    
-- IF TAKEALL = YES AND TOOKALL <> YES THEN UPDATE PIECES IN SOURCE LENGTH AND SOURCE UNIT BY BALANCE
IF @takeALL = 1 and @tookALL = 0 BEGIN 
    Update UnitLengths set qtyOnHand = @balance where ID = @sourceUnitLengthID
    Update Units set piecesStock = piecesStock + @balance where ID = @sourceUnitID
    END
    
-- IF TAKEALL = NO AND TOOKALL = YES THEN ZERO OUT THE PIECES IN THE SOURCE UNIT LENGTH, BUT 1ST, UPDATE THE SOURCE UNIT BY THE DELTA
IF @takeALL = 0 and @tookALL = 1 BEGIN
    Update Units set piecesStock = piecesStock - L.qtyOnHand 
        FROM Units U inner join UnitLengths L on L.ob_Units_RID = U.ID
        where L.ID = @sourceUnitLengthID
     
    Update UnitLengths set qtyOnHand = 0 where ID = @sourceUnitLengthID
    END 
    
-- IF ANY MODIFICATIONS DONE, THEN UPDATE THE UM IN THE SOURCE AND TARGET UNITS
IF @take <> @took or @takeAll <> @tookAll BEGIN
    update Units SET UMStock = ROUND(L.totalLF / I.LFperUM,0)
    from Units U inner join Items I on U.ob_Items_RID = I.ID
    inner join (select L.ob_Units_RID, sum(length * qtyOnHand) as totalLF
        from UnitLengths L group by L.ob_Units_RID) as L on L.ob_Units_RID = U.ID
    where U.ID = @sourceUnitID
    
    update Units SET UMStock = ROUND(L.totalLF / I.LFperUM,0)
    from Units U inner join Items I on U.ob_Items_RID = I.ID
    inner join (select L.ob_Units_RID, sum(length * qtyOnHand) as totalLF
        from UnitLengths L group by L.ob_Units_RID) as L on L.ob_Units_RID = U.ID
    where U.ID = @targetUnitID
    END
    
select 'Success' as message
GO
