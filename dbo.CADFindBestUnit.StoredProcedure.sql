USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CADFindBestUnit]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CADFindBestUnit]   
 
-- last change 10/31/2018
-- last change 03/24/2022 -- changed sort for inplay and fixed date logic for inplay

@orderLineID    integer,
@Item           integer,
@SkipIntact     integer = 0,
@designDate     date,
@UnitID         integer OUT

AS

declare @is3PL integer
select @is3pl = case when C.reloadCustomer = 1 then -1 else 1 end 
    from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    where L.ID = @orderLineID

set @UnitID = null
;

with w as (
    select U.ID
        from Units U
        where U.ob_Items_RID = @Item and U.UMStock > 0
        and U.ps_OrderLines_RID is null
        and U.ID Not in (Select ps_Unit_RID from CADSourceUnits WHERE ps_OrderLines_RID = @OrderLineID)
        and U.ID not in (select ps_Units_RID from ORDERUNITS where ps_units_RID IS NOT NULL)
)


select  top 1 @UnitID = unitID from (select U.ID as unitID,
    sum(case when QtyOnHand > CADBalance then CADBalance else QtyOnHand end) as totalPieces,
    max(U.dateEntered) as dateEntered,
    max(case when C.unitNumber IS NULL then 0 else 1 end) as inPlay,
    max(case when @skipIntact = 1 and U.unitType = 'I' then 1 else 0 end) as intactFlag

    From UnitLengths L 
    inner join Units U on L.ob_Units_RID = U.ID
    inner join OrderTally T on L.length = T.length
    left outer join (select distinct C.unitNumber 
        from CADTransactions C
        inner join CADDrills D on C.ps_CADDrills_RID = D.ID
        inner join OrderLines L on L.ID = C.ps_OrderLines_RID
        where D.designDate = @designDate AND (L.designStatus = 'Des' or L.designStatus = 'W/P')
        
        ) as  C on C.unitNumber = U.ID  
    
    
    where T.ob_OrderLines_RID = @OrderLineID
    and U.ob_Items_RID = @Item
    and (U.condition is null or left(U.condition,1) <> 'X' or U.condition = '')
    and (U.pocketwoodFlag <> 1 or U.unitType <> 'I') -- ADDED 07/12/23
    and L.QtyOnHand > 0
    and T.CADBalance > 0
    and U.missingFlag <> 1 
    and U.lostFlag <> 1
    and U.doNotUseForDesign <> 1        -- ADDED 08/20/22
    and U.ID in (select ID from w)
    group by U.ID) as Z

where totalPieces > 0
order by inplay desc, intactFlag, totalPieces desc




/*

with w as (select  U.ID as unitID,
    sum(case when QtyOnHand > CADBalance then CADBalance else QtyOnHand end) as totalPieces,
    max(U.dateEntered) as dateEntered,
    max(case when C.ID IS NULL then 1 else 0 end) as inPlay,
    max(case when @skipIntact = 1 and U.unitType = 'I' then 1 else 0 end) as intactFlag

    From UnitLengths L 
    inner join Units U on L.ob_Units_RID = U.ID
    inner join OrderTally T on L.length = T.length
    left outer join CADTRANSACTIONS C on C.unitNumber = U.ID
    where T.ob_OrderLines_RID = @OrderLineID
    and U.ob_Items_RID = @Item
    and L.QtyOnHand > 0
    and T.CADBalance > 0
    and U.ID Not in (Select ps_Unit_RID from CADSourceUnits WHERE ps_OrderLines_RID = @OrderLineID)
    and U.ID not in (select ps_Units_RID from ORDERUNITS)
    group by U.ID)
    
select  top 1 @unitID = unitID from w
where totalPieces > 0
order by inplay, intactFlag, totalPieces desc

*/
GO
