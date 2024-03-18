USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ComputeWholeUnitsInCADDrill]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[ComputeWholeUnitsInCADDrill]
@DrillID integer

as

update CADDRILLS 
    set noWhole = ISNULL(X.noWhole,0)
    from  CADDRILLS inner join (select count(*) as noWhole from 
            ORDERLINES L
            inner join ORDERUNITS OU on OU.ob_OrderLines_RID = L.ID
            WHERE L.ps_CADDrills_RID = @DrillID and OU.wholeUnitAssigned = 1) as X on 1 = 1
      
where ID = @DrillID
GO
