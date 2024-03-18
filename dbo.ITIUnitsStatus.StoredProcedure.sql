USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ITIUnitsStatus]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[ITIUnitsStatus]
as
select oldcode as code, internalDescription as item,
sum(case when U.condition = '(Sort!' then U.UMStock else 0 end) as oldTotal,
sum(case when U.condition = '(Sort!' then 0 else U.UMStock end) as newTotal

from Items I inner join Units U on I.ID = U.ob_Items_RID
where (left(I.oldCode,3) = '0QJ' or left(I.oldCode,3) = '0QK')
and U.UMStock > 0
group by oldCode, internalDescription
order by oldCode, internalDescription
GO
