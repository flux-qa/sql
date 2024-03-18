USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadSubstituteUnitsAllUnits]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadSubstituteUnitsAllUnits]
    
    @sourceUnit integer = 642763

    as
    declare @itemID integer
    
    DELETE from SubstituteUnits
    select @itemID = ob_Items_RID from Units where unit = @sourceUnit
    
    Insert into SubstituteUnits (ID, BASVERSION, BASTIMESTAMP, unit, unitTally, ps_OrderLines_REN, ps_OrderLines_RID, orderNumberAssignedTo)


    Select row_Number() over (order by unit) as ID, 1 as BASVERSION, getdate() as BASTIMESTAMP,
    unit, dbo.unitTallyToString(U.ID) as unitTally, 
    case when L.ID IS NULL then null else 'OrderLines' end as orderLines_REN,
    case when L.ID is null then null else L.ID end as orderLines_RID,  
    case when L.orderLineForDisplay IS NULL then '' else L.orderLineForDisplay end as assignedTo

    from Units U left outer join OrderLines L on U.ps_OrderLines_RID = L.ID
    
    where U.ob_Items_RID = @itemID AND U.UMstock > 0 and U.unitType = 'I' AND U.Unit <> @sourceUnit
    and U.dateWorkPapersProcessed is null
    
    order by U.unit
GO
