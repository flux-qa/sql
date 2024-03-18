USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[N_ItemsShipments]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create procedure [dbo].[N_ItemsShipments]
@firstDate date = '03/01/2019', 

@lastDate date = '03/31/2019'

as
 
select I.oldCode as item, I.internalDescription as description, 
sum(UMShipped) as shipped, max(I.avgCost) as cost

from Items I inner join OrderLines L on L.ob_Items_RID = I.ID
where left(I.oldCode,1)='N' and
L.dateShipped between @firstDate and @lastDate
group by I.oldCode, I.internalDescription
order by I.internalDescription
GO
