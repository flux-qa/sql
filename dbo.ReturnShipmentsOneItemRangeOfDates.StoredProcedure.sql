USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReturnShipmentsOneItemRangeOfDates]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReturnShipmentsOneItemRangeOfDates]

    @inventoryID    integer,
    @noDays         integer,
    @UMShipped      integer OUT,
    @noOrders       integer OUT
    
AS    
    
DECLARE
    @fromdate       date,
    @thruDate       date
    
set @fromDate = dateadd(yy, -1, getdate())
set @thruDate = dateadd(dd, @noDays, @fromDate)
    
select @UMShipped = sum(UMShipped), @noOrders = count(*)
    from OrderLines where ob_items_RID = @inventoryID AND
    dateShipped >= @fromDate and dateadd(dd, 1, @thruDate) > dateShipped
GO
