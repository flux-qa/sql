USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateHandleOrderTransactions]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateHandleOrderTransactions]
@drillID        integer
 
-- last change 02/05/24 
 
as 

delete from HandleOrderTransactions where drillID = @drillID 
 

INSERT INTO [dbo].[HandleOrderTransactions]([ID], [BASVERSION], [BASTIMESTAMP], 
sourceUnitNumber, [length], lengthText, [take], takeAll, modifier, balance, [undigTo],  
[drillID], bay, [sourceUnitDug],
[ob_HandleOrderTargets_REN], [ob_HandleOrderTargets_RID], 
[ps_Unit_REN], [ps_Unit_RID]) 
 
 
select next value for mySeq, 1, getdate(), 
    SU.unit, UL.length, cast(UL.length as varchar(2)) + '''', T.take, T.takeAll,
    case when T.modifier = '=' then 'EXACT'
        when T.modifier = '<' then 'Max' 
        when T.modifier = '>' then 'Min' else '' end as modifier, 
    balance, UML.undigTo,
    T.ps_CADDrills_RID, SU.location as bay, 0,
    'HandleOrderTargets', H.ID,
    'Unit', SU.ID
    from CADTransactions T inner join UnitLengths UL on T.ps_UnitLengths_RID = UL.ID
    inner join Units SU on UL.ob_Units_RID = SU.ID
    inner join Units TU on T.ps_TargetUnit_RID = TU.ID
    inner join HandleOrderTargets H on TU.unit = H.targetUnitNumber
    left outer join (select ob_Items_RID, maxLen, location as undigTo
    from UndigByMaxLen) UML 
        on UML.ob_Items_RID = SU.ob_Items_RID and UML.maxLen = SU.longLength
    where T.ps_CADDrills_RID = @drillID
GO
