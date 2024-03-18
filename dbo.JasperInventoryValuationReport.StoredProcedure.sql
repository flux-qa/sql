USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[JasperInventoryValuationReport]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[JasperInventoryValuationReport]
@skipConsignment integer = 0,
@skipDefective   integer = 0,
@skipPocketWood  integer = 0,
@useMktCost      integer = 0
as
select oldCode as code, internalDescription as item, 
case when @skipConsignment = 1 then I.UMStock - I.consignmentUM when @skipConsignment = 2 
then I.consignmentUM else I.UMStock end as Stock, UM, 
case when @useMktCost = 0 OR I.mktCost = 0 OR I.mktCost > I.avgCost then I.avgCost else I.mktCost end as avgCost,
 
case when umPer = 1000 then 'M' when umPer = 100 then 'C' when umPer = 12 then 'D' when umPer = 10 then 'X' else 'E' end as per,
ROUND(case when @skipConsignment = 1 then (I.UMStock - I.consignmentUM) 
when @skipConsignment = 2 then I.consignmentUM else I.UMStock end * 
case when @useMktCost = 0 OR I.mktCost = 0 OR I.mktCost > I.avgCost then I.avgCost else I.mktCost end / umper,2) as value, 
 0 as noUnits, 0 as minCost, 0 as maxCost

from Items I where  (I.UMStock - I.consignmentUM > 0 and @skipConsignment = 1) OR
	(I.consignmentUM > 0 and @skipConsignment = 2) OR 
	(I.UMStock > 0  and @skipConsignment = 0) 

order by oldCode
GO
