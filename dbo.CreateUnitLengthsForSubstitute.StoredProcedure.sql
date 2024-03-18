USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateUnitLengthsForSubstitute]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateUnitLengthsForSubstitute]
@unitID         integer = 630191,
@CADDrillID     integer = 1610990

as

declare @itemID integer
declare @unitRealID integer

select @itemID = ob_Items_RID, @unitRealID = ID from Units where unit = @unitID

delete from UnitLengthsForSubstituteUnit
;
with w as (select 'Units' as ob_Units_REN, U.ID as ob_Units_RID, null as ob_Units_RMA, 
    Z.length, '<b>' + rtrim(cast(Z.length as char(2))) + '''</b>' as lengthString
    from Units U full outer join (    
    select C.length, sum(take) as take
        from CADTransactions C right outer join UnitLengths L on C.ps_UnitLengths_RID = L.ID 
        where L.ob_Units_RID = @unitRealID AND C.ps_CADDrills_RID = @CADDrillID group by C.length) as Z on 1 = 1   
    left outer join UnitLengths L on U.ID = L.ob_Units_RID and L.length = Z.length
    where U.ob_Items_RID = @itemID and U.piecesStock > 0
    and U.unitType <> 'T'
    
union

select  
    'Units', U.ID as ob_Units_RID, null, 
    L.length, '<b>' + rtrim(cast(L.length as char(2))) + '''</b>'
    --case when take is null then L.qtyOnHand else qtyOnHand - take end
    from Units U inner join UnitLengths L on U.ID = L.ob_Units_RID
    left outer join CADTransactions T on T.ps_UnitLengths_RID = L.ID and T.length = L.length
        and T.ps_CADDrills_RID = @CADDrillID
    where U.ob_Items_RID = @itemID and U.piecesStock > 0
    and U.unitType <> 'T')


INSERT INTO [dbo].[UnitLengthsForSubstituteUnit]
([ID], [BASVERSION], [BASTIMESTAMP], 
 [ob_Units_REN], [ob_Units_RID], [ob_Units_RMA], 
 [length], [lengthString],
 [piecesStock], [piecesRequired], balance)     
  
    
select row_number() over (order by w.ob_units_RID, w.length), 1, getDate(),  

w.ob_Units_REN, w.ob_Units_RID, w.ob_Units_RMA, w.length, w.lengthString, 
L.qtyOnHand, z.take,
case when L.qtyOnHand is null then -take else L.qtyOnHand - take end as balance
 from w left outer join (select C.length, sum(take) as take, max(l.qtyOnHand) as piecesStock
    from CADTransactions C inner join UnitLengths L on C.ps_UnitLengths_RID = L.ID 
    where L.ob_Units_RID = @unitRealID AND C.ps_CADDrills_RID = @CADDrillID group by C.length) as Z
    on Z.length = w.length
    left outer join UnitLengths L on L.ob_Units_RID = w.ob_units_RID and L.length = W.length

-- NOW FLAG THE UNITS THAT ARE NOT OK TO SUBSTITUTE and UNITS in CURRENT DRILL
Update Units set OKToSubstitute = 1, unitInCurrentDrill = 0  where ob_Items_RID = @ItemID

Update Units set OKToSubstitute = 0 where ob_Items_RID = @ItemID AND
    Units.ID in (select ob_Units_RID from UnitLengthsForSubstituteUnit where balance < 0)
    
Update Units set UnitInCurrentDrill = 1 where ob_Items_RID = @ItemID AND
    Units.ID in (select ob_Units_RID 
    from UnitLengths L inner join CADTransactions T on L.ID = T.ps_UnitLengths_RID
    where T.ps_CADDrills_RID = @CADDrillID)
GO
