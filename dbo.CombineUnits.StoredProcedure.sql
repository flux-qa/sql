USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CombineUnits]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CombineUnits]

-- CALLED AFTER WORK PAPER FOR A UNIT IS PROCESSED
-- FINDS ALL OF THE SOURCES THAT *NO* LONGER HAVE AN UNPOSTED TARGET UNIT
-- AND ARE ON THE LIST OF UNITS TO COMBINE


as


declare @noValidRecords integer

-- 0TH, CREATE TEMP TABLE WITH VALID IDS OF UNITS TO COMBINE
if OBJECT_ID('tempdb.dbo.#ValidUnitsToCombine', 'U') IS NOT NULL
    drop table #ValidUnitsToCombine

select ID into #ValidUnitsToCombine from unitsToCombine Z

where  not exists (
select distinct C.ps_TargetUnit_RID 
    from UnitsToCombine UC inner join CADTransactions C on UC.targetUnit_RID  = C.unitNumber
    inner join Units U on C.ps_TargetUnit_RID = U.ID
    inner join OrderLines L on U.ps_OrderLines_RID = L.ID
    where L.designStatus =  'Des'
    and Z.ID = UC.ID)

and not exists (    
select distinct C.ps_TargetUnit_RID 
    from UnitsToCombine UC inner join CADTransactions C on UC.sourceUnit_RID  = C.unitNumber
    inner join Units U on C.ps_TargetUnit_RID = U.ID
    inner join OrderLines L on U.ps_OrderLines_RID = L.ID
    where L.designStatus = 'Des'
    and Z.ID = UC.ID)

-- IF NO VALID UNITS TO COMBINE, EXIT
select @noValidRecords = count(*) from #ValidUnitsToCombine
IF @noValidRecords = 0
    RETURN 0


-- 1ST, CREATE LENGTHS IN TARGET(S) THAT DO NOT EXIST IN SOURCE
BEGIN TRANSACTION

    
    INSERT INTO UnitLengths (ID, BASVERSION, BASTIMESTAMP,
        ob_Units_REN, ob_Units_RID, ob_Units_RMA, length, qtyOnHand)
    
    select next value for BAS_IDGEN_SEQ, 1, getdate(),     
        'Units', UC.targetUnit_RID as targetID, 'om_UnitLengths', length, 0
    from UnitLengths L inner join UnitsToCombine UC on L.ob_Units_RID = UC.sourceUnit_RID
        
    WHERE NOT EXISTS (select 1 from UnitLengths L2 
        inner join UnitsToCombine UC2 on L2.ob_Units_RID = UC2.targetUnit_RID
         WHERE L2.length = L.length and UC2.targetUnit_RID = UC.targetUnit_RID) 
           

COMMIT TRANSACTION

-- 2ND, UPDATE THE PIECES IN THE TARGET(S)

BEGIN TRANSACTION

update UnitLengths
   set qtyOnHand = QtyOnHand + V.sourceQtyOnHand,
   UMOnHand = ROUND((L.QtyOnHand + V.sourceQtyOnHand) * L.length / V.LFperUM,0)

--select L.ID as targetLengthID, L.Length, l.qtyOnHand, V.targetLength, V.sourceQtyOnHand, V.LFperUM
    from UnitLengths L inner join UnitsToCombineView V on L.ID = V.targetLengthID
    where V.ID in (select ID from #ValidUnitsToCombine)
    
-- 3RD, ZERO OUT QTY'S IN SOURCE UNIT
update unitLengths set qtyOnHand = 0, UMOnHand = 0
from UnitLengths L inner join UnitsToCombine C on L.ob_Units_RID = C.sourceUnit_RID
where C.ID in (select ID from #ValidUnitsToCombine)

-- 4TH CLEAR QUANTITIES IN UNIT HEADER FROM SOURCE
update Units set UMStock = 0, piecesStock = 0
from Units U inner join UnitsToCombine C on U.ID = C.sourceUnit_RID
where C.ID in (select ID from #ValidUnitsToCombine)

-- 5TH, DELETE THE UnitsToCombine RECORDS    
delete UnitsToCombine
where ID in (select ID from #ValidUnitsToCombine)

COMMIT TRANSACTION

-- RECOMPUTE the UNIT TOTALS
exec UpdateUnitsFromUnitLengths
GO
