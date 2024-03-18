USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[SubstituteSourceUnitInCAD]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SubstituteSourceUnitInCAD]


-- MAJOR CHANGE (REWRITE) ON 02/26/19
-- Change on 2/6/20 to create logic for SubQuery

        @CADDrillID     integer = 0,
        @originalUnit   integer = 0,
        @newUnit        integer = 0
 
as


declare @OUnitNumber integer
declare @NUnitNumber integer

select @OUnitNumber = unit from Units where ID = @originalUnit
select @NUnitNumber = unit from Units where ID = @newUnit


Insert into MyAwareLog (comment, ID, numericComment)
    values ('Substituting Source Unit', @originalUnit, @newUnit)

-- 1st Update Original Source Unit Lengths
    update UnitLengths set qtyOnHand = qtyOnHand + totalTake
        from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
        inner join (select T.unitNumber, T.length, sum(take) as totalTake from 
        CADTransactions T where T.ps_CADDrills_RID = @CADDrillID group by T.unitNumber, T.length) as Z
            on Z.unitNumber = U.unit and Z.length = L.length
        WHERE U.ID = @OriginalUnit         

    
-- 2nd Update New Unit Lengths
    update UnitLengths set qtyOnHand = case when isnull(totalTake,0) > qtyOnHand then 0 else qtyOnHand - isNull(totalTake,0) end
        from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
        
        inner join (select T.unitNumber, T.length, sum(take) as totalTake from 
        CADTransactions T where T.ps_CADDrills_RID = @CADDrillID AND T.unitNumber = @OUnitNumber 
            group by T.unitNumber, T.length) as Z
            on Z.unitNumber = @OUnitNumber and Z.length = L.length
        WHERE U.ID = @newUnit          
      
    
-- Finally, Update the CAD Transactions

Update CADTransactions
    set ps_UnitLengths_RID = L.ID,
    unitNumber = @NUnitNumber
    
    FROM CADTransactions C inner join UnitLengths L on C.length = L.length and L.ob_Units_RID = @newUnit
    
    WHERE C.ps_CADDrills_RID = @CADDrillID
    AND C.unitNumber = @OUnitNumber
GO
