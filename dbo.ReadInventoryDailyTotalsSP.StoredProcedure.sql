USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadInventoryDailyTotalsSP]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[ReadInventoryDailyTotalsSP]

@code varchar(5)

as

delete from InventoryDailyTotalsSP

INSERT INTO [dbo].[INVENTORYDAILYTOTALSSP]([ID], [BASVERSION], [BASTIMESTAMP], 
[UMConsignment], [code], [UMOpenPO], [UMAvail], [UMStock], [UMShipped], [UMPocket], 
[UMReceived], [dateUpdated]) 

select next Value For mySeq, 1, getdate(),
I.UMConsignment, I.oldCode, I.UMOpenPO, I.UMAvailable, I.UMStock, I.UMShipped, I.UMPocketwood,
I.UMReceived, cast(I.dateUpdated as date)
 


    from InventoryDailyTotals I
        where oldCode = @code and dateUpdated > dateadd(dd, -90, getdate())
GO
