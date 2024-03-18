USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UnitAnalysisSingleLengthSpecificItems]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UnitAnalysisSingleLengthSpecificItems]


as

SET NOCOUNT ON



declare @StartOfMonth date =  DATEADD(month, DATEDIFF(month, 0, getDate()), 0)
declare @CurrentYear integer = datePart(yy, getDate())
declare @LastYear integer = @currentYear - 1

declare @monthsThisYear integer = datePart(mm, @startOfMonth) - 4

if @MonthsThisYear <= 0 begin
    set @MonthsThisYear = 0
end

if @MonthsThisYear > 6 
    set @MonthsThisYear = 6

declare @monthsLastYear integer = 6 - @monthsThisYear

declare @FromDateCurrentYear date = '04/01/' + cast(@currentYear as char(4))
declare @FromDatePreviousYear date = dateAdd(yy, -1, @StartOfMonth)
declare @thruDatePreviousYear date = '10/01/' + cast(@lastyear as char(4))

--select @startOfMonth,  @currentyear, @lastYear,  @monthsThisYear, @monthsLastyear, @fromDateCurrentYear, @fromDatePreviousyear, @thruDatePreviousYear

--select 'selecting Shipped Orders >= ' , @fromDateCurrentYear , ' < ', @startOfMonth , '  and >= ' , @fromDatePreviousYear, ' < ' , @thruDatePreviousYear

;
with w as (
select distinct L.ob_Items_RID as item, 
UL.Length, count(Distinct datePart(yy, L.dateShipped) * 1000 +
datePart(dy, L.dateShipped)) as noDays

from OrderLines L inner join OrderUnits OU on L.ID = OU.ob_OrderLines_RID
Inner join Units U on U.ID = OU.ps_Units_RID
inner join UnitLengths UL on U.ID = UL.ob_Units_RID
where ((L.dateShipped >=  @fromDateCUrrentYear and L.dateShipped  < @StartOfMonth) OR
(L.dateShipped >= @fromDatePreviousYear and L.dateShipped < @thruDatePreviousYear)) AND
U.unit > 600000 and UL.length > 1 
/*
and L.ob_Items_RID in (
select distinct I.ID
from units U inner join Items I on U.ob_Items_RID = I.ID
where U.UMStock > 0 and U.unitType = '')
*/
group by L.ob_Items_RID, UL.length)

select I.oldCode as item, w.length, I.internalDescription as description,  
noDays, itemDays, handledUnits, noLengths
from w inner join Items I on w.item = I.ID
inner join (select item, max(noDays) as itemDays from w group by item) as X on I.ID = X.item

left outer join (select  I.ID, count(*) as handledUnits
from units U inner join Items I on U.ob_Items_RID = I.ID
where U.UMStock > 0 and U.unitType = '' group by I.ID
) as y on I.ID = Y.ID

left outer join (
select item, max(noLengths) as noLengths from (
select ob_Items_RID as item, U.ID, count(distinct length) as noLengths 
from units U inner join UnitLengths UL on U.ID = UL.ob_Units_RID
where unittype = 'I' and UMStock > 0
group by ob_Items_RID, U.id) as foo group by item) as Z on I.ID = Z.item


where  I.oldCode in ('113B',
                                     '228R',
                                     '2CT4',
                                     'A336',
                                     '162A',
                                     '0BD6',
                                     '1667',
                                     'A386',
                                     '2CT6',
                                     '0E16',
                                     '0N11',
                                     '6I56',
                                     '2CT8',
                                     '220R',
                                     '0BT4',
                                     'A388',
                                     '2C0R',
                                     '1L05',
                                     '16AJ',
                                     '6I46',
                                     '0BT2',
                                     '0L84',
                                     '0T6Z',
                                     '14AJ',
                                     '2C8R',
                                     '0B16',
                                     '2C6R',
                                     '16AX',
                                     '0036',
                                     'A434',
                                     '1V4S'
)

order by I.oldCode , w.length
GO
