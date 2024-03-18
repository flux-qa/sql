USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateBayTotalsInchesToFeet]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create Procedure [dbo].[UpdateBayTotalsInchesToFeet]

as

Update BayTotals set availFeetInches = dbo.InchesToFeet(availableInches)
GO
