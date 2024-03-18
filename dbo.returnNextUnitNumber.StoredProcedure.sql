USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[returnNextUnitNumber]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[returnNextUnitNumber]
@unitNumber     int out 
as
select @unitNumber = next value for unitNumberSeq
GO
