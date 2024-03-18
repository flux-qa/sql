USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[DiggerOneBayComplete]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DiggerOneBayComplete]
@digger    integer

AS

Update DiggerOneBay
    SET status = 'Complete',
    dateMarkedComplete = getdate(),
    completeFlag = 1
    where digger = @digger and completeFlag = 0
GO
