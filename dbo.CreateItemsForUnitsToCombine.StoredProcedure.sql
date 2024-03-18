USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateItemsForUnitsToCombine]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateItemsForUnitsToCombine]
@CADDrillID integer = 1500748

as



delete from ItemsForUnitsToCombine
delete from UnitsForUnitsToCombine
;

with w as (
select U.ob_Items_RID as itemID, count(Distinct U.ID) as noSourceUnits, 
    sum(L.qtyOnHand) as pieces, sum(L.length * L.qtyOnHand) as LFStock
    from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
    inner join Units U on L.ob_Units_RID = U.ID
    where T.ps_CADDrills_RID = @CADDrillID and L.qtyOnHand > 0
    group by U.ob_Items_RID having count(distinct U.ID) > 1)

insert into ItemsForUnitsToCombine (ID, BASVERSION, BASTIMESTAMP,
    itemID, oldCode, description, noSourceUnits, pieces, UMStock)
    
select row_number() over (order by w.itemID), 1, getDate(), 
    W.itemID, I.oldCode, I.internalDescription as description, W.noSourceUnits,
    W.pieces, round(W.LFStock / I.LFperUM,0) as UMStock
    from W inner join Items I on W.itemID = I.ID
GO
