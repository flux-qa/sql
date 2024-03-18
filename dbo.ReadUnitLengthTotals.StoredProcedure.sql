USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadUnitLengthTotals]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadUnitLengthTotals]
--
-- 12/22/15
-- 01/21/16 -- fixed logic in calculating unitUM
-- 07/21/23 -- added non pocketwood total
--

@Item   integer,
@Unit   integer,
@AccessLevel    varchar(60)

as

set NOCOUNT ON


select row_number() over (order by L.length) as ID, max(1) as BASVERSION, max(getDate()) as BASTIMESTAMP,
    L.length, rtrim(cast(L.length as char(2))) + '''' as lengthString, 
    sum(qtyOnHand) - max(isNull(totAllocated,0)) as totPcs, 
    sum(case when U.pocketWoodFlag = 0 then qtyOnHand else 0 end) - max(isNull(totAllocated,0)) as availPcs,
    round(sum(L.length * qtyOnHand / I.LFperUM) - max(isNull(totAllocated,0) * L.length / I.lfPerUM),0) as totUM,
    count(distinct L.unit) as noUnits, max(unitPcs) as unitPcs, max(unitUM) as unitUM, 
    cast(round(100 * sum(L.length * qtyOnHand / I.LFperUM) / Max(case when I.UMStock < 1 then 1 else I.UMStock end),2) as decimal(6,2)) as pctTotal, round(max(pctUnit),2) as pctUnit
    from UnitLengths L inner join Units U on L.ob_units_RID = U.ID
    inner join Items I on U.ob_Items_RID = I.ID
    left outer join (select length, sum(qtyOnHand) as unitPcs, round(sum(length * qtyOnHand / I.LFperUM),0) as unitUM,
        100.0 * sum(L.length * qtyOnHand / I.LFperUM) / Max(U.UMStock + U.UMRolling)  as pctUnit
        from UnitLengths L inner join Units U on L.ob_units_RID = U.ID
        inner join Items I on U.ob_Items_RID = I.ID
        where U.ID = @Unit group by Length) as Z on L.length = Z.length
        
    left outer join (select L.ob_Items_RID, T.length, sum(T.pieces) as totAllocated 
        from OrderTally T inner join OrderLines L on T.ob_OrderLines_RID = L.ID
        where L.UMShipped = 0 and L.WRD = 'W'
        group by L.ob_Items_RID, T.length) as Y on Y.ob_Items_RID = I.ID and Y.length = L.length   

    where I.ID = @Item and L.qtyOnHand > 0 and U.lostFlag = 0 and
    (@AccessLevel = 'Administrator' OR @AccessLevel = 'Manager' or @AccessLevel = 'OPS' OR U.pocketwoodFlag = 0)
    group by L.length
    order by L.length
GO
