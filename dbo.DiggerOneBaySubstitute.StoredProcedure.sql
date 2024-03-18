USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[DiggerOneBaySubstitute]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DiggerOneBaySubstitute]

-- last change 10/16/23

@ID integer,
@substitute integer

as

Update DiggerOneBay 
    set originalUnitNumber = unitNumber,
    unitNUmber = @substitute,
    status = 'Substituted'
    where ID = @ID
    --and completeFlag = 0
GO
