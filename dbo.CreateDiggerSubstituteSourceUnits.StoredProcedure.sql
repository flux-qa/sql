USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateDiggerSubstituteSourceUnits]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateDiggerSubstituteSourceUnits]

-- last change 10/16/23

@sourceUnit     integer = 714463,
@designDate     date,
@drillNumber    integer

as

declare @item           integer,
        @originalRcvd   date
select @item = ob_Items_RID, @originalRcvd = ISNULL(dateReceived, dateEntered)
    from Units where unit = @sourceUnit

delete from DiggerSubstituteUnits WHERE sourceUnit = @sourceUnit

;

-- MAKE UP TEMP TALLY FOR LENGTHS USED FOR THIS DESIGN DATE AND DRILL
with w as (select  T.length, sum(T.take) as take
    from CADTransactions T inner join CADDrills D on T.ps_CADDrills_RID = D.ID
    inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
    inner join Units U on L.ob_Units_RID = U.ID
    where U.ob_Items_RID = @item and D.designDate = @designDate 
        and D.drillNumber = @drillNumber
    group by T.length)


insert into DiggerSubstituteUnits (ID, BASVERSION, BASTIMESTAMP, 
    sourceUnit, substituteUnit, dateReceived, daysOlder, UMStock)
    Select Next Value for mySeq, 1, getDate(), @sourceUnit, U.unit,
        max(ISNULL(U.dateReceived, dateEntered)) as dateReceived, 
        max(datediff(dd, @originalRcvd, ISNULL(dateReceived, dateEntered))) as age, 
        max(U.UMStock) as UMStock
    from Units U inner join UnitLengths L on L.ob_Units_RID = U.ID
    inner join W on W.length = L.Length
        where U.ob_Items_RID = @item
        and U.UMStock > 0 and U.missingFlag = 0 and U.lostFlag = 0
        and U.ID not in (select L.ob_Units_RID from CADTransactions T 
            inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID 
            inner join CADDrills D on T.ps_CADDrills_RID = D.ID
            where D.designDate = @designDate and D.drillNumber = @drillNumber)
    group by U.unit 
    having count(*) = sum(case when L.qtyOnHand >= W.take then 1 else 0 end)
GO
