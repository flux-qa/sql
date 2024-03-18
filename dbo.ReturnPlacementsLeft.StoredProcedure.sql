USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReturnPlacementsLeft]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReturnPlacementsLeft]
@digger     integer,
@noPlacements   integer OUT


as

Select @noPlacements = COUNT(*) 
    from DiggerOneBay
    where digger = @digger
    and completeFlag = 0
    --and status <> 'Placed'
    --and status <> 'Skipped'
GO
