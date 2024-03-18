USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[HighUsageItemsByMaxLen]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HighUsageItemsByMaxLen]


@fromDate   date = '03/01/2021',
@thruDate   date = '09/30/2021'

as

declare @totDays integer = datediff(dd, @fromDate, @thruDate)

;
;
with Z as (select distinct I.ID as inventoryID, U.unit, 
        ISNULL(UL.longLength,0) as maxLen   
        from CADTransactions T inner join Units U on T.unitNumber = U.unit
        inner join Items I on U.ob_Items_RID = I.ID
        inner join (select ob_Units_RID, max(length) as longLength from UnitLengths where originalQty > 0 group by ob_Units_RID) as UL
            on UL.ob_Units_RID = U.ID
        inner join CADDrills D on T.ps_CADDrills_RID = D.ID
        where D.designDate between @fromDate and @thruDate),

W as (select I.oldcode as code, I.internalDescription as item,
    UML.maxLength as maxLen , count(*) as noUnits, count(*) * max(UML.inchesHigh) as totalInches, max(UML.inchesHigh) as inchesHigh, max(bayName) as bayName 
    from Z inner join Items I on Z.inventoryID = I.ID
    inner join UnitMaxLenData UML on UML.ob_Item_RID = I.ID and Z.maxLen = UML.maxLength
    group by I.oldcode, I.internalDescription, UML.maxLength),
    
    
X as(select I.oldCode as code, 
    UL.longLength as maxLen, sum(UDT.UMStock)   as totStock, count(*) as noUnitsForAverage, count(distinct dateCreated) as daysStock
    from UnitDailyTotals UDT inner join Units U on UDT.ob_Units_RID = U.ID
    inner join Items I on UDT.ob_Items_RID = I.ID
    inner join (select ob_Units_RID, max(length) as longLength from UnitLengths where originalQty > 0 group by ob_Units_RID) as UL
            on UL.ob_Units_RID = U.ID            
    where  UDT.dateCreated between @fromDate and @thruDate and U.unitType <> 'T'
    group by I.oldCode, UL.longLength)    
           
select w.code, w.item, w.maxLen, w.noUnits + isnull(WU.noWholeUnits,0) as noUnits,
    isnull(WU.noWholeUnits,0) as wholeUnits, w.totalInches, 
    round(100.0 * w.noUnits / totalUnits, 2) as pctUnits,
    round(100.0 * totalInches / grandTotalInches,2) as pctInches, round(X.noUnitsForAverage / X.daysStock,0) as avgNoUnits, 
    @totDays - X.daysStock + 1 as StockOutDays, @totDays as noOfDays, X.daysStock as daysWithStock, W.inchesHigh, W.bayName
    from W inner join X on W.code = X.code and W.maxLen = X.maxLen
    left outer join (select I.oldCode, U.longLength, count(*) as noWholeUnits
    from OrderLines L inner join Units U on U.ps_OrderLines_RID = L.ID
    inner join Items I on U.ob_Items_RID = I.ID
    where L.dateShipped between @fromDate and @thruDate and U.unitType <> 'T'
    group by I.oldCode, U.longLength) as WU on WU.oldcode = W.code and WU.longLength = W.maxLen
    
    inner join (select sum(noUnits) as totalUnits, sum(totalInches) as grandTotalInches from W) as Y on 1 = 1
GO
