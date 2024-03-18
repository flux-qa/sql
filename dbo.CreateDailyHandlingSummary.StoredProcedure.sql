USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateDailyHandlingSummary]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateDailyHandlingSummary]

as

with w as (
select I.CADHandle, count(Distinct ps_targetUnit_RID) as noTargets,
    count(distinct unitNumber) as noSources
    from CADTRANSACTIONS T 

    inner join UNITS U on T.unitNumber = U.unit
    inner join ITEMS I on U.ob_Items_RID = I.ID
    inner join CADDRILLS CD on CD.ID = T.ps_CADDrills_RID
         
    Where CD.designDate >= cast(getDate() as date)
    
    group by I.CADHandle)

    

select row_number() over (order by CADHandle) as ID, 1 as BASVERSION, getdate() as BASTIMESTAMP, 
    CADHandle, noTargets, noSources
    from W order by CADHandle
GO
