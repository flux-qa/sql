USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[JasperServerDiggingInstructions]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[JasperServerDiggingInstructions] 


@designDate     date = '02/15/2023',
@drillNumber    integer = 1

-- last change 02/15/23 -- added nextCode and nextHandle

AS

;
with w as (select A.source, A.minNID, A.noUnits, row_number() over (partition by A.source order by A.noUnits desc) as rowno 
from (select Z.unit as source, N.ID as minNID, Z.noUnits
from newHandleOrders N 
inner join (select T.ps_OrderLines_RID, U.unit,  max(Y.noUnits) as noUnits 
    from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
    inner join Units U on L.ob_Units_RID = U.ID
    inner join (select T.ps_OrderLines_RID as orderLineID, count(distinct L.ob_Units_RID) as noUnits
        from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID 
        group by T.ps_OrderLines_RID) as Y on Y.orderLineID = T.ps_OrderLines_RID
    group by T.ps_OrderLines_RID, U.unit) as Z 
    on Z.ps_OrderLines_RID = N.ps_OrderLines_RID 
where N.designDate = @designDate and N.drillNumber = @drillNumber) as A)

select case when N.west4East0 = 4 then 'West' else 'East' end as side, N.rowNumber, I.oldCode as code, 
I.internalDescription as item, Z.unit as sourceUnit,  left(N.handleLocationAlpha,1)  as handle, 
N.orderNo, '' as extra, Z.longLength, 
    Z.location,
/*    case 
    when 1 = 1 then Z.location
    when len(Z.location)  = 4 or left(Z.location,1) = 'C' or left(Z.location,2) = '1L' or left(Z.location,2) = '0R'
    then Z.location 
    when (left(N.handleLocationAlpha,1) < '5' or N.handleLocationAlpha = 'East')
     then 'East' else 'West' end as location, 
 */   
	 case when IP.Unit is NOT NULL then 'InPlay' else '' end as inPlay,
	 lead(I.oldCode)  over(partition by N.west4East0 order by rowNumber, Z.longLength desc, N.noSource) as nextCode,
	 	 lead(left(N.handleLocationAlpha,1)) 
		 over(partition by N.west4East0 order by rowNumber, Z.longLength desc, N.noSource) as nextHandle, 
		 case when DUP.noOrders > 1 then cast(DUP.noOrders as varchar(2)) + ' Targets' else '' end as dupOrders
from newHandleOrders N inner join Items I on N.ps_Items_RID = I.ID
inner join OrderLines L on N.ps_OrderLines_RID = L.ID
inner join (select distinct T.ps_OrderLines_RID, U.unit, U.longLength, U.location
from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
inner join CADDrills D on T.ps_CADDrills_RID = D.ID
inner join Units U on L.ob_Units_RID = U.ID
where D.designDate = @designDate and D.drillNumber = @drillNumber
) as Z 
    on Z.ps_OrderLines_RID = N.ps_OrderLines_RID
inner join W on W.source = Z.unit and W.minNID = N.ID
-- SEE IF THIS UNIT IS USED IN A PREVIOUS DRILL
left outer join (select distinct U.unit
    from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
    inner join Units U on L.ob_Units_RID = U.ID
    inner join CADDrills D on T.ps_CADDrills_RID = D.ID
    where D.designDate = @designDate and D.drillNumber < @drillNumber) as IP on IP.unit = Z.unit


-- SEE IF THIS UNIT IS USED IN MULTIPLE ORDERS
left outer join (select U.unit, count(Distinct T.ps_OrderLines_RID) as noOrders
    from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
    inner join Units U on L.ob_Units_RID = U.ID
    inner join CADDrills D on T.ps_CADDrills_RID = D.ID
    where D.designDate = @designDate and D.drillNumber  = @drillNumber group by U.Unit) as DUP on DUP.unit = Z.unit
	
	
where N.designDate = @designDate and N.drillNumber = @drillNumber and W.rowno = 1

order by 1, rowNumber, Z.LongLength desc, N.noSource
GO
