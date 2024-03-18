USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateServerInstructionsForMobile]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[CreateServerInstructionsForMobile]



@designDate     date = '12/05/2023',
@drillNumber    integer = 1

-- last change 02/15/23 -- added nextCode and nextHandle

as

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


Insert into ServerInstructions (ID, BASVERSION, BASTIMESTAMP,
    area, rownumber, code, item, sourceUnit, handle, orderNumber, 
    longLength, location, inplay, nextCode, nextHandle, dupOrders, designDate, drillNumber, placed, qtyUM  )

select next value for myseq, 1, getdate(), case when N.west4East0 = 4 then 'West' else 'East' end as side, N.rowNumber, I.oldCode as code, 
I.internalDescription as item, Z.unit as sourceUnit,  left(N.handleLocationAlpha,1)  as handle, 
N.orderNo, Z.longLength,  Z.location, 
	 case when IP.Unit is NOT NULL then 1 else 0 end as inPlay,
	 lead(I.oldCode)  over(partition by N.west4East0 order by rowNo, Z.longLength desc, N.noSource) as nextCode,
	 	 lead(left(N.handleLocationAlpha,1)) 
		 over(partition by N.west4East0 order by rowNo, Z.longLength desc, N.noSource) as nextHandle, 
		 case when DUP.noOrders > 1 then cast(DUP.noOrders as varchar(2)) + ' Targets' else '' end as dupOrders, 
		 @designDate, @drillNumber, 0, format(Z.UMStock, '##,###') + ' ' + Z.UM
from newHandleOrders N inner join Items I on N.ps_Items_RID = I.ID
inner join OrderLines L on N.ps_OrderLines_RID = L.ID
inner join (select distinct T.ps_OrderLines_RID, U.unit, U.longLength, U.location, U.UMStock, I.UM
from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
inner join CADDrills D on T.ps_CADDrills_RID = D.ID
inner join Units U on L.ob_Units_RID = U.ID
inner join Items I on U.ob_Items_RID = I.ID
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

left outer join ServerInstructions SI on SI.designDate = @designDate and SI.drillNumber = @drillNumber and SI.sourceUnit = Z.unit	
	
where N.designDate = @designDate and N.drillNumber = @drillNumber and W.rowno = 1 and SI.ID IS NULL
GO
