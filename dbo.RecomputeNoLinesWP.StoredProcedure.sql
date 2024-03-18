USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[RecomputeNoLinesWP]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[RecomputeNoLinesWP]
AS
update Orders set noLinesWP = noWP, 
    wpPostedToLinesString = 
    rtrim(cast(noWP as char(2))) + ' of ' + rtrim(cast(noLines as char(2)))

from Orders O inner join (select L.ob_Orders_RID, 
    sum(case when L.designStatus = 'W/P'then 1 else 0 end) as noWP
    from OrderLines L where L.UMShipped = 0 group by L.ob_Orders_RID)
    as Z on Z.ob_Orders_RID = O.ID
GO
