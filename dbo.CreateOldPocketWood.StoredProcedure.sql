USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateOldPocketWood]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateOldPocketWood]

as

delete from OLDPOCKETWOOD

insert into OldPocketWood(ID, BASVERSION, BASTIMESTAMP,
    code, item, UM, noPocketWood, UMPocketWood, oldPocketWood, newPocketWood,
    noUnits, UMStock, oldUnit, newUnit, PWDates, NonPWDates, daysOld)

select I.ID as ID, 1 as BASVERSION, getDate() as BASTIMESTAMP,

I.oldCode as code, I.internalDescription as item, I.UM,
    noPocketWood, P.UMPocketWood, oldPocketWood, newPocketWood,
    noUnits, U.UMStock, oldUnit, newUnit,
    case when OldPocketWood = newPocketWood then convert(char(8), oldPocketWood,1) else
        convert(char(8), oldPocketWood,1) + ' - ' + convert(char(8), newPocketWood,1) end as PWDates,
    case when oldUnit = newUnit then convert(char(8), oldUnit,1) else    
        convert(char(8), oldUnit,1) + ' - ' + convert(char(8), newUnit,1) end as NonPWDates,
    dateDiff(dd, oldPocketWood, newUnit) as daysOld
    
    from Items I 
    
    inner join (select U.ob_Items_RID as itemID, count(*) as noPocketWood, sum(UMStock) as UMPocketWood, 
        cast(min(dateReceived) as date) as oldPocketWood, cast(max(dateReceived) as date) as newPocketWood
        from Units U
        where U.UMStock > 0 and U.pocketWoodFlag = 1 and U.lostFlag = 0 group by U.ob_Items_RID) as P on I.ID = P.itemID
        
    inner join (select U.ob_Items_RID as itemID, count(*) as noUnits, sum(UMStock) as UMStock, 
        cast(min(dateReceived) as date) as oldUnit, cast(max(dateReceived) as date) as newUnit
        from Units U
        where U.UMStock > 0 and U.pocketWoodFlag = 0 and U.lostFlag = 0group by U.ob_Items_RID) as U on I.ID = U.itemID
        
    where dateAdd(dd, 61, oldPocketWood) < newUnit
GO
