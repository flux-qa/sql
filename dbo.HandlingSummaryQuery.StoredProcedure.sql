USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[HandlingSummaryQuery]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HandlingSummaryQuery]
@DrillID integer = 1093218

as


declare @drillNumber integer,
@designDate date

select @drillNumber = drillNumber, @designDate = designDate from CADDRILLS where ID = @drillID

;


with w as (
select distinct case when NHO.handleLocationAlpha IS NULL then 'X' when NHO.handleLocationAlpha < '5' OR NHO.handleLocationAlpha = 'East' then 'E' else 'W' end as handleArea, 
@drillNumber as drillNumber, @designDate as designDate, 
'Target' as type, T.ps_TargetUnit_RID as unitNumber

    from CADTRANSACTIONS T
    inner join ORDERLINES L on T.ps_OrderLines_RID = L.ID
        left outer join NewHandleOrders NHO on NHO.ps_OrderLines_RID = L.ID
    inner join ITEMS I on L.ob_Items_RID = I.ID
    where T.ps_CADDrills_RID = @DrillID and L.designStatus <> ''

union all

select distinct case when NHO.handleLocationAlpha IS NULL then 'X' when NHO.handleLocationAlpha < '5' OR NHO.handleLocationAlpha = 'East' then 'E' else 'W' end as handleArea,  
@drillNumber as drillNumber, @designDate as designDate, 
'Source' as type, unitNumber

    from CADTRANSACTIONS T
    inner join ORDERLINES L on T.ps_OrderLines_RID = L.ID
        left outer join NewHandleOrders NHO on NHO.ps_OrderLines_RID = L.ID
    inner join ITEMS I on L.ob_Items_RID = I.ID
    where T.ps_CADDrills_RID = @DrillID and L.designStatus <> ''

union all

select distinct case when NHO.handleLocationAlpha IS NULL then 'X' when NHO.handleLocationAlpha < '5' OR NHO.handleLocationAlpha = 'East' then 'E' else 'W' end as handleArea,  
@drillNumber as drillNumber, @designDate as designDate, 
'PreviousTargets' as type, T.ps_TargetUnit_RID as unitNumber

    from CADTRANSACTIONS T
    inner join ORDERLINES L on T.ps_OrderLines_RID = L.ID
        left outer join NewHandleOrders NHO on NHO.ps_OrderLines_RID = L.ID
    inner join ITEMS I on L.ob_Items_RID = I.ID
    inner join CADDRILLS D on T.ps_CADDrills_RID = D.ID
    where D.designDate = @DesignDate and D.drillNumber < @drillNumber and L.designStatus = 'Des'

union all

select distinct case when NHO.handleLocationAlpha IS NULL then 'X' when NHO.handleLocationAlpha < '5' OR NHO.handleLocationAlpha = 'East' then 'E' else 'W' end as handleArea,  
@drillNumber as drillNumber, @designDate as designDate, 
'PreviousSources' as type, unitNumber

    from CADTRANSACTIONS T
    inner join ORDERLINES L on T.ps_OrderLines_RID = L.ID
        left outer join NewHandleOrders NHO on NHO.ps_OrderLines_RID = L.ID
    inner join ITEMS I on L.ob_Items_RID = I.ID
    inner join CADDRILLS D on T.ps_CADDrills_RID = D.ID
    where D.designDate = @DesignDate and D.drillNumber < @drillNumber and L.designStatus = 'Des'
)

select handleArea, drillNumber, designDate, type, count(unitNumber) as noUnits
from W 
    group by handleArea, drillNumber, designDate, type
    order by handleArea, type
GO
