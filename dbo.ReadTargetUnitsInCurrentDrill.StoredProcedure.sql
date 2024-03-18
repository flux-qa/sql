USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadTargetUnitsInCurrentDrill]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadTargetUnitsInCurrentDrill]

@CADDrillID integer


as



delete CurrentDrillTargetUnits

INSERT INTO [dbo].[CURRENTDRILLTARGETUNITS]([ID], [BASVERSION], [BASTIMESTAMP], 
[orderNumber], [designTime], [targetUnit], [piecesInTransactions], [piecesInTarget], wholeUnit) 

select row_number() over (order by U.unit) as id, 1 as BASVERSION, getDate() as BASTIMESTAMP, 
    orderNumber,  designTime, U.unit, 
    case when U.wholeUnitAssigned = 1 then piecesInTarget else isNull(piecesInTransaction,0) end as piecesInTransaction,  
    isNull(piecesInTarget,0) as piecesInTarget, isNull(U.wholeUnitAssigned, L.wholeUnits) as wholeUnitAssigned
  
    from  Units U inner join OrderLines L on U.ps_OrderLines_RID = L.ID
    
    left outer join (select U.ID, sum(take) as piecesInTransaction, 
        cast(max(T.BASTIMESTAMP) as time) as designTime
        from CADTransactions T inner join CADDrills D on T.ps_CADDrills_RID = D.ID
        inner join OrderLines L on T.ps_OrderLines_RID = L.ID
        inner join Units U on U.ps_OrderLines_RID = L.ID where D.ID = @CADDrillID group by U.ID) as T on T.ID = U.ID 
        
    left outer join (select ob_Units_RID, sum(qtyOnHand) as piecesInTarget from UnitLengths group by ob_Units_RID) as Z
        on U.ID = Z.ob_Units_RID
    
    where L.ps_CADDrills_RID = @CADDrillID 
    
order by U.unit desc
GO
