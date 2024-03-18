USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdatePurchaseLinesQuantitySold]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdatePurchaseLinesQuantitySold]

as

update purchaseLines set quantitySold = 0
update purchaseLines set quantitySold = totalSold
from PurchaseLines L inner join (select ps_PurchaseLines_RID, sum(umOrdered) as totalSold from OrderLines
group by ps_PurchaseLines_RID) as Z on Z.ps_PurchaseLines_RID = L.ID
GO
