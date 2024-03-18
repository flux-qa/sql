USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[LostVsFoundUnits]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[LostVsFoundUnits]


@fromDate date = '12/25/2019',
@thruDate date = '01/30/2020'

as

select I.oldCode as code, I.internalDescription as item, U.unit, U.location, U.UMStock, I.UM,
    round(-1 * U.UMStock * case when I.avgCost = 0 then I.lastCost else I.avgCost end / I.UMPer, 0) as value, 'Lost' as type
    from Units U inner join Items I on U.ob_Items_RID = I.ID
    where U.dateLost between @fromDate and @thruDate

   
UNION ALL

select I.oldCode as code, I.internalDescription as item, U.unit, U.location, U.UMStock, I.UM,
    round(U.UMStock * case when I.avgCost = 0 then I.lastCost else I.avgCost end / I.UMPer, 0) as value, 'Found' as type
    from Units U inner join Items I on U.ob_Items_RID = I.ID
    where U.dateFound between @fromDate and @thruDate

ORDER BY I.oldCode, U.unit
GO
