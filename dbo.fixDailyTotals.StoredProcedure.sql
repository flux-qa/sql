USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[fixDailyTotals]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[fixDailyTotals]

@dateUpdated date

as

INSERT INTO [dbo].[InventoryDailyTotals]( [inventoryID], dateupdated, [oldCode], [LFStock], [UMStock], [LFOpenPO], [UMOpenPO], [avgCost]) 
select ID, @dateUpdated, oldCode, LFStock, UMStock, LFOpenPO, UMOpenPO, avgCost from alcawaretest.dbo.ITEMS
GO
