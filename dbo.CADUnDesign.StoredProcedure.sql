USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CADUnDesign]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CADUnDesign]

@OrderLineID integer,
@DrillID     integer

as
-- last change 01/14/17


declare @NumberOfTargets integer
declare @Item integer
declare @LFToUM float
declare @maxID integer
declare @pcsBundle integer
declare @UnitID integer
declare @loopCounter integer = 1
declare @noCADTransactions integer
declare @drillDate date 


-- UPDATE SOURCE UNIT LENGTHS FROM THE TAKE IN THE CADTRANSACTIONS
Update UNITLENGTHS set qtyOnHand = QtyOnHand + T.take
from CADTRANSACTIONS T
inner join UNITLENGTHS L on T.ps_UnitLengths_RID = L.ID
where T.ps_OrderLines_RID = @orderLineID


delete from UNITLENGTHS where ob_Units_RID in (
    select ID from UNITS WHERE ps_OrderLines_RID = @OrderLineID AND Units.unitType = 'T' and Units.wholeUnitAssigned <> 1)

delete from UNITS WHERE ps_OrderLines_RID = @OrderLineID AND Units.unitType = 'T'
delete from CADSOURCELENGTHS WHERE ps_OrderLines_RID = @orderLineID
delete from CADTRANSACTIONS WHERE ps_OrderLines_RID = @OrderLineID

-- REMOVE DESIGNED UNITS FROM ORDERUNITS
delete from ORDERUNITS 
WHERE ob_OrderLines_RID = @OrderLineID and wholeUnitAssigned = 0

update CADDRILLS 
    set noTarget = distinctTargets,
    noSources = distinctSources,
    noDead = numberOfDead,
    noOrderLines = noOrderLines - 1
    from CADDRILLS C inner join (
        select T.ps_CADDrills_RID as drillNo, count(distinct ps_UNIT_RID) as distinctSources, 
            count (distinct ps_TargetUnit_RID) as distinctTargets,

            sum(case when S.balance = 0 then 1 else 0 end) as numberOfDead
            from  CADSOURCEUNITS S 
            inner join CADTRANSACTIONS T on S.ps_OrderLines_RID = T.ps_orderLines_RID
            where T.ps_CADDrills_RID = @DrillID
            group by T.ps_CADDrills_RID) as Z on C.ID = Z.drillNo

        
where ID = @DrillID   


update CADDRILLS 
    set noWhole = ISNULL(X.noWhole,0)
    from  CADDRILLS inner join (select count(*) as noWhole from 
            ORDERLINES L
            inner join ORDERUNITS OU on OU.ob_OrderLines_RID = L.ID
            WHERE L.ps_CADDrills_RID = @DrillID and OU.wholeUnitAssigned = 1) as X on 1 = 1
      
where ID = @DrillID 

--exec updateUnitsFromUnitLengths @Item

exec CADPreProcess @OrderLineID

INSERT INTO MyAwareLog ( [comment],  [numericComment]) 
	VALUES('CAD Design Cancelled', @orderLineID)
GO
