USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CADProcess]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CADProcess]         
@OrderLineID integer,
@DrillID     integer

as 

-- 05/08/18 - UPDATE UNIT PCS AND UM
-- 10/03/18 - FIXED BUG WHERE WOULD USE ALL OF THE DESIGNED EVEN IF ANOTHER ITEM CODE
-- 11/13/18 - CREATE LENGTH STRING

declare @NumberOfTargets integer
declare @Item integer
declare @LFperUM float
declare @maxID integer
declare @pcsBundle integer
declare @UnitID integer
declare @loopCounter integer = 1
declare @drillDate date 
declare @noTarget integer

set @drillDate = getDate()


-- GET # OF TARGETS SO FAR
select @noTarget = noTarget from CADDRILLS where ID = @DrillID

-- READ INVENTORY CONVERSIONS
Select @Item = L.ob_Items_RID,
    @PcsBundle = pcsBundle,
    @LFperUM = I.LFperUM
    from OrderLines L inner join Items I on L.ob_Items_RID = I.ID 
    where L.ID = @OrderLineID

select @NumberOfTargets = count(*) from UNITS 
    WHERE ps_OrderLines_RID = @OrderLineID and LFStock IS NULL

-- DELETE ANY TRANSACTIONS, SOURCELENGTHS AND SOUCE UNITS WHERE USER CHANGED QTY TO 0
delete from CADTRANSACTIONS WHERE ps_OrderLines_RID = @OrderLineID and take = 0
delete from CADSOURCELENGTHS WHERE ps_OrderLines_RID = @OrderLineID and take = 0
delete from CADSOURCEUNITS WHERE ps_OrderLines_RID = @OrderLineID and taken = 0


-- SAVE ORIGINAL TAKE -- 4/26/23 -- UPDATE DESIGN ACCEPTED FLAG
update CADTransactions set takeOriginal = take, designAccepted = 1 where ps_OrderLines_RID = @OrderLineID

--Declare myCursor CURSOR local  FAST_FORWARD for
    select top 1 @unitID = ID from UNITS WHERE ps_OrderLines_RID = @OrderLineID and LFStock IS NULL
    order by ID

--open myCursor        
--fetch next from myCursor into @UnitID
--while (@@fetch_status = 0)
--    begin 

    -- UPDATE THE TARGET # IN UNITS
    set @noTarget = @noTarget + 1
    update UNITS set targetNumber = @noTarget where ID = @UnitID
    
    Update Units set actualCost = I.avgCost
        From Units U inner join Items I on U.ob_Items_RID = I.ID
        where U.ID = @UnitID


        update CADTRANSACTIONS set ps_TargetUnit_RID = @UnitID, ps_TargetUnit_REN = 'Units' 
            WHERE ps_OrderLines_RID = @OrderLineID and ps_TargetUnit_RID IS NULL
        

    
    -- REDUCE THE QTYONHAND IN SOURCE UNIT UNITLENGTHS
    update UNITLENGTHS set qtyOnHand = qtyOnHand - take
    from UNITLENGTHS L inner join CADTRANSACTIONS C ON C.ps_UnitLengths_RID = L.ID
    where C.ps_OrderLines_RID = @OrderLineID
    
    -- CLEAR INTACT FLAG
    Update Units set unitType = '', date1stHit = case when date1stHit is null then getDate() else date1stHit end 
    from Units U inner join UnitLengths L on L.ob_Units_RID = U.ID
    inner join CADTRANSACTIONS C ON C.ps_UnitLengths_RID = L.ID
    where C.ps_TargetUnit_RID = @UnitID AND U.unitType = 'I'

    -- INSERT PIECES INTO TARGET UNITLENGTH    
    INSERT INTO [dbo].[UNITLENGTHS]([ID], [BASVERSION], [BASTIMESTAMP], 
    unit, length, qtyOnHand, UMOnHand, LFOnHand,  [originalQty], 
    [ob_Units_REN], [ob_Units_RID], [ob_Units_RMA], lengthString) 

    select next value for BAS_IDGEN_SEQ, 1, getDate(),
        @unitID, length, take, round(length * take / @LFperUM,0), length * take, take,
        'Units', @UnitID, 'om_UnitLengths', rtrim(cast(length as char(2))) + ''''
        from (select length, sum(take) as take
        from CADTRANSACTIONS
                WHERE ps_TargetUnit_RID = @UnitID
        group by length) as Z
        

-- IF ANY WHOLE UNITS UPDATE THE RELATIONSHIP IN THE ORDER FILE TO THE UNIT
Update UNITS 
set ps_OrderLines_REN = 'OrderLines', ps_OrderLines_RID = L.ID
from UNITS U inner join ORDERUNITS OU on OU.ps_Units_RID = U.ID
inner join ORDERLINES L ON OU.ob_OrderLines_RID = L.ID
WHERE OU.ob_OrderLines_RID = @OrderLineID and OU.wholeUnitAssigned = 1



-- SET ALL OF THE TRANSACTIONS FOR THIS ORDER TO THE SELECTED DRILL #
update CADTRANSACTIONS 
    set ps_CADDrills_RID = @DrillID, 
    ps_CADDrills_REN = 'CADDrills' 
    where ps_orderLines_RID = @OrderLineID

update CADDRILLS 
    set noTarget = noTarget + @NumberOfTargets,
    noSources = z.noSource,
    noDead = z.noDead,
    noWhole = ISNULL(X.noWhole,0),
    noOrderLines = y.noOrderLines,
    dateLastDesign = getDate(),
    dateFirstDesign = case when dateFirstDesign is null then getdate() else dateFirstDesign end
    from CADDRILLS C inner join (
        select count(*) as noSource, 
            sum(case when noDeadUnits = 0 then 1 else 0 end) as noDead from (
            select S.ps_UNIT_RID as sourceUnitNo , min (S.balance) as noDeadUnits
            from  CADSOURCEUNITS S 
            inner join CADTRANSACTIONS T on S.ps_OrderLines_RID = T.ps_orderLines_RID
            where T.ps_CADDrills_RID = @DrillID
        group by S.ps_Unit_RID) as Z) as Z on 1=1

        left outer join (select count(*) as noWhole from 
            ORDERLINES L
            inner join ORDERUNITS OU on OU.ob_OrderLines_RID = L.ID
            WHERE L.ps_CADDrills_RID = @DrillID and OU.wholeUnitAssigned = 1) as X on 1 = 1
        

    inner join (select count(distinct ps_orderLines_RID) as noOrderLines
        from CADTRANSACTIONS
            where ps_CADDrills_RID = @DrillID) as Y on 1=1

where ID = @DrillID 

update CADDRILLS 
    set noWhole = ISNULL(X.noWhole,0)
    from  CADDRILLS inner join (select count(*) as noWhole from 
            ORDERLINES L
            inner join ORDERUNITS OU on OU.ob_OrderLines_RID = L.ID
            WHERE L.ps_CADDrills_RID = @DrillID and OU.wholeUnitAssigned = 1) as X on 1 = 1
      
where ID = @DrillID

-- MAKE SURE OrderLines Design Status updated
Update OrderLines set designStatus = 'Des' WHERE ID = @OrderLineID

-- UDPATE UNIT FROM THE LENGTHS
exec UpdateUnitsFromUnitLengths @Item
GO
