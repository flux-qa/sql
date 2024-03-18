USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdatePocketWoodUsedInCADTally]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[UpdatePocketWoodUsedInCADTally]
as


Update PocketWoodUsedInCAD set tally = dbo.OrderTallyToString(ps_OrderLines_RID)
where tally is null
GO
