USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateWPPostedMessage]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateWPPostedMessage]
as 

Update Orders set noLines = totLines, noLinesWP = isNull(totLinesWP,0),
    wpPostedToLinesString = case when totLines = totLinesWP then 'Ready' else
    cast(isNull(totLinesWP,0) as char(2)) + ' of ' + cast(totLines as char(2)) end
from Orders O inner join (select ob_Orders_RID, count(*) as totLines, 
    sum(case when designStatus = 'W/P' then 1 else 0 end) as totLinesWP
    from OrderLines where dateShipped is null group by ob_Orders_RID) as Z on O.ID = Z.ob_Orders_RID
where O.dateShipped is null
GO
