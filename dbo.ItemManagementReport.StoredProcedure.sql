USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ItemManagementReport]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ItemManagementReport]

as

declare
    @currentDate    date,
    @oneYearAgo     date,
    @twoyearsAgo    date
    
set @currentDate    = getdate()
set @oneYearAgo     = dateAdd(yy, -1, @currentDate)
set @twoYearsAgo    = dateAdd(yy, -2, @currentDate)
;

with currentSales as 
    (select ob_items_RID, sum(UMShipped) as currentUM from OrderLines
    where dateShipped between @oneYearAgo and @currentDate
    group by ob_Items_RID),
    
    lastYearSales as 
    (select ob_items_RID, sum(UMShipped) lastYearUM from OrderLines
    where dateShipped between @twoYearsAgo and @oneYearAgo
    group by ob_Items_RID)

    
select left(I.buyer,2) as buyer, I.oldCode as code, I.internalDescription as item, 'Hot / Cold Items' as msg,
    'LY: ' + format(isNull(lastyearUM,0), '###,##0') + '  CY: ' +  format(isNull(currentUM,0), '###,##0') + '  Growth: ' +
    case when lastyearUM is null or lastYearUM = 0 then '100%'
        when currentUM is null then '-100%'
        else format(round(100.0 * (currentUM - lastYearUM) / lastYearUM,0), '###,##0') + '%' end as comments
        
   from currentSales C full outer join lastYearSales L on C.ob_Items_RID = L.ob_Items_RID
   inner join Items I on I.ID = ISNULL(C.ob_Items_RID, L.ob_Items_RID)
   where (currentUM is null or lastYearUM is null or abs(isnull(currentUM,0) - isnull(lastYearUM,0)) * 2 > isnull(currentUM, lastYearUM))
   and I.buyer is not null and I.buyer <> '' and left(I.oldcode,1) <> '{'


union all
   
select left(I.buyer,2) as buyer, I.oldCode as code, I.internalDescription as item, 'Low Avail. with PW' as msg, 
    'Avail: ' + format(noAvailable, '##0') + '   Pocket: ' + format(noPocketWood, '##0') as comments
    from Items I inner join (select U.ob_Items_RID, 
        sum(case when pocketwoodFlag = 1 then 0 else 1 end ) as noAvailable,
        sum(case when pocketwoodflag = 1 then 1 else 0 end) as noPocketWood
        from Units U
        where U.UMStock > 0 and U.unitType = 'I'
        group by U.ob_Items_RID) as PW on I.ID = PW.ob_Items_RID
    where PW.noPocketWood > 2 and PW.noAvailable < 2
    
union all

    select left(I.buyer,2) as buyer, I.oldCode as code, I.internalDescription as item, 'Old PocketWood' as msg,
    format(noAvailable, '#,###') + ' Avail Units ' + 
    case when noAvailable = 0 then '0' else format(availDays / noAvailable, '#,###') end + ' Days   ' + 
    format(noPocketwood, '#,###') + ' PW Units ' + case when noPocketWood = 0 then '0'  else 
    format(pocketWoodDays / noPocketWood, '#,###') end + ' Days' as comment
   
    from Items I inner join (select U.ob_Items_RID, 
        sum(case when pocketwoodFlag = 1 then 0 else 1 end ) as noAvailable,
        sum(case when pocketwoodFlag = 1 then 0 else datediff(dd, U.dateEntered, getDate()) end) as availDays,
        sum(case when pocketwoodflag = 1 then 1 else 0 end) as noPocketWood,
        sum(case when pocketwoodFlag = 1 then datediff(dd, U.dateEntered, getDate()) else 0 end) as pocketWoodDays

        from Units U
        where U.UMStock > 0 and U.unitType = 'I'
        group by U.ob_Items_RID) as PW on I.ID = PW.ob_Items_RID
        where noPocketWood > 0 and noAvailable > 0 
        and availDays / case when noAvailable < 1 then 1 else noAvailable end * 2 < pocketwoodDays / case when noPocketWood < 1 then 1 else noPocketWood end
    order by buyer, msg, I.internalDescription
GO
