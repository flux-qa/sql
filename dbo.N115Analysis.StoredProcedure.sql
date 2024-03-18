USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[N115Analysis]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[N115Analysis]


@Item char(4),
@fromDate date ,
@thruDate date

as

select I.oldCode as Item, dateUpdated,  DT.UMStock
    from InventoryDailyTotals DT inner join ITEMS I on DT.inventoryID = I.ID
where I.oldcode = @Item AND
dateUpdated between @fromDate and @thruDate


order by I.oldCode
GO
