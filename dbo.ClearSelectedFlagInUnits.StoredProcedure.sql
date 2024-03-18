USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ClearSelectedFlagInUnits]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ClearSelectedFlagInUnits]

as

Update Units set selectedFlag = 0 WHERE UMStock > 0
GO
