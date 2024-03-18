USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateContractorInstructions]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateContractorInstructions]
as
update orderLines set contractorInstructions = '' where UMShipped = 0

Update OrderLines set contractorInstructions = OLSC.description
from Orders O
inner join OrderLines L  on L.ob_Orders_RID = O.ID
inner join OrderLineServiceCharges OLSC on OLSC.ob_OrderLines_RID = L.ID
inner join Contractors CO on CO.ID = OLSC.ps_Contractor_RID and CO.ps_Customers_RID = O.ob_Customers_RID
where L.UMShipped = 0
GO
