USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[DailyStockAnalysis]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DailyStockAnalysis]

        @item varchar(4),
        @fromDate   date,
        @thruDate   date,
        @showAll    integer = 0
as
       
       
with w as (select row_number() over (partition by IDT.inventoryID order by IDT.dateUpdated ) as rowNo,
    I.ID as inventoryID, I.oldcode as code, --I.internalDescription as item,
    cast(dateadd(dd, -1, IDT.dateUpdated) as date) as entered, IDT.UMStock, 
    ROUND(isNull(R.LFReceived,0) / I.LFperUM,0) as UMReceived, isnull(S.UMShipped,0) as UMShipped,
    round(isNull(UA.origQty,0) / I.LFperUM,0) as origQty, round(isNull(UA.newQty,0) / I.LFperUM,0) as newQty,
    round(isNull(UA.newQty,0) / I.LFperUM,0) - round(isNull(UA.origQty,0) / I.LFperUM,0) as deltaAdjustment,
    round(isNull(SA.suaAdjust,0) / I.LFperUM,0) as suaAdjust
    from InventoryDailyTotals IDT inner join Items I on IDT.inventoryID = I.ID

    
    left outer join (select U.ob_Items_RID, cast(U.dateReceived as date) as dateReceived,
        sum(L.length * L.originalQty) as LFReceived
        from Units U inner join UnitLengths L on L.ob_Units_RID = U.ID
        where U.ps_PurchaseLines_RID > 0
        group by U.ob_Items_RID, cast(U.dateReceived as date)) as R 
            on R.ob_Items_RID = I.ID and cast(dateadd(dd, -1, IDT.dateUpdated) as date) = R.dateReceived
            
    
    left outer join (select ob_Items_RID, cast(dateShipped as date) as dateShipped, sum(UMShipped) as UMShipped
    from OrderLines group by ob_Items_RID, cast(dateShipped as date)) as S on S.ob_Items_RID = I.ID
    and cast(dateadd(dd, -1, IDT.dateUpdated) as date) = S.dateShipped
    
    
    
    left outer join (select U.ob_Items_RID as itemID, cast(A.entered as date) as entered,
    sum(A.length * A.originalQty) as origQty, sum(A.length * A.newQty) as newQty

    from UnitLengthsAdjustmentLog A inner join UnitLengths L on A.ps_UnitLengths_RID = L.ID
    inner join Units U on L.ob_Units_RID = U.ID
    group by U.ob_Items_RID, cast(a.entered as date)) as UA on UA.itemID = I.ID and 
        cast(dateadd(dd, -1, IDT.dateUpdated) as date) = UA.entered
    
    
    left outer join (select U.ob_Items_RID as itemID, cast(A.entered as date) as entered,
    sum(A.length * A.take - A.took) as suaAdjust
    from SourceUnitAdjustmentLog A inner join UnitLengths L on A.ps_SourceUnitLength_RID = L.ID
    inner join Units U on L.ob_Units_RID = U.ID
    where A.tookAll = 1
    group by U.ob_Items_RID, cast(a.entered as date)) as SA on SA.itemID = I.ID and 
        cast(dateadd(dd, -1, IDT.dateUpdated) as date) = SA.entered
    
    where I.oldCode like @item + '%' and
        IDT.dateUpdated between @fromDate and @thruDate)
        
        
select  w.code, I.internalDescription as item, w.entered, --I.internalDescription as item, 
x.UMStock as prevUM, w.UMStock,  w.deltaAdjustment as [Rcvd&Adj], w.UMShipped,
        x.UMStock + w.deltaAdjustment - W.UMShipped + W.suaAdjust as calcQty, 
        W.UMStock - (x.UMStock + W.deltaAdjustment + W.suaAdjust - W.UMShipped) as delta,
        W.suaAdjust
        from W inner join W as X on W.inventoryID = X.inventoryID and w.rowno - 1 = X.rowno
        inner join Items I on W.inventoryID = I.ID
        
        where W.UMstock <> x.UMStock + w.deltaAdjustment - W.UMShipped + W.suaAdjust OR @showAll = 1
        --or W.UMShipped <> 0 
        
        order by w.code, w.entered
GO
