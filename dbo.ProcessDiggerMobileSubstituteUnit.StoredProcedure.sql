USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ProcessDiggerMobileSubstituteUnit]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ProcessDiggerMobileSubstituteUnit]

-- last change 01/30/24

@digID              integer,
@substituteUnit     integer,
@originalTier       varchar(12)

as

Update DiggerMobile set 
    unitNumber = @substituteUnit,
    status ='Substitute', 
    tierCurrentUnit = @originalTier,
    isSub = 1
    
where ID = @digID
GO
