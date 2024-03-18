USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateHandleTargetSources]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateHandleTargetSources]

-- last change 02/15/24



@designDate     date = '02/12/24',
@drillNumber    integer = 1

as

declare @CADDrillID     integer

select @CADDrillID = ID from CADDrills 
    where designDate = @designDate and drillNumber = @drillNumber


delete from HandleTargetSources WHERE ps_CADDrills_RID = @CADDrillID


INSERT INTO [dbo].[HANDLETARGETSOURCES]([ID], [BASVERSION], [BASTIMESTAMP], 
[ob_HandleTargetMobile_REN], [ob_HandleTargetMobile_RID], [ob_HandleTargetMobile_RMA], 
ps_CADDrills_REN, ps_CADDrills_RID,
[ps_SourceUnit_REN], [ps_SourceUnit_RID], isPlaced, bay, undigTo, piecesUsed) 


select next value for mySeq, 1, getDate(),
'HandleTargetMobile', MID, 'om_HandleTargetSources',
'CADDrills', @CADDrillID,
'Units', UID, 0, bay, undigTo, totalTake

from (select distinct M.ID as MID, U.ID as UID, U.location as bay, 
    ISNULL(UD.undigTo, '????') as unDigTo, totalTake
        FROM CADTransactions T inner join HandleTargetMobile M on 
        T.ps_TargetUnit_RID = M.ps_TargetUnit_RID
        inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
        inner join Units U on L.ob_Units_RID = U.ID
        left outer join (Select ob_Items_RID, maxlen, 
            location as undigTo from UndigByMaxLen) 
                as UD on UD.ob_Items_RID = U.ob_Items_RID
                and UD.maxLen = U.longLength
        left outer join (select ps_UnitLengths_RID as ULID, ps_TargetUnit_RID as TUID, sum(take) as totalTake 
            from CADTransactions group by ps_UnitLengths_RID, ps_Targetunit_RID) as W on W.ULID = T.ps_UnitLengths_RID and W.TUID = T.ps_TargetUnit_RID         
        where T.ps_CADDrills_RID = @CADDrillID) as Z
GO
