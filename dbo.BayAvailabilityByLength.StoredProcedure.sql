USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[BayAvailabilityByLength]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[BayAvailabilityByLength]

as


select A.aisleName, B.maxLen, count(*) as noBays,
       sum(case when B.availableInches > 0 then 1 else 0 end) as baysWithSpace,
       sum(case when B.availableInches > 0 then B.availableInches else 0 end) as availInches
    from BayTotals B inner join Aisles A on A.leftBank = left(b.bay,1) or A.rightBank = left(B.bay,1)
group by A.aisleName, B.maxLen
order by A.aisleName, B.maxLen
GO
