USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadDiggerMobile]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadDiggerMobile]
@digger     integer

-- last change 03/11/24

as

declare @norecs integer

-- SEE IF ANY RECORDS TO DISPLAY, IF NOT THEN CREATE NEW SET OF DIGS
select @norecs = count(*) FROM DiggerMobile 
    WHERE digger = @digger and datePlaced is null and dateSkipped is null
    
if @noRecs = 0 BEGIN
    exec CreateDiggerMobile @digger
    
    select @norecs = count(*) FROM DiggerMobile 
        WHERE digger = @digger and datePlaced is null and dateSkipped is nulL
     
    
    IF @NORECS = 0
        select  'There are NO More Digs for Digger #: ' + cast(@digger as varchar(3)) as item
    ELSE
        SELECT id as digID, digger, bay, unitNumber, destination, code, item, maxLen, cast(pieces as integer) as pieces,
        status, cast(wholeUnit as integer) as wholeUnit,  
        cast(noSubstituteUnits as integer) as noSubstituteUnits, originalUnitNumber, isSub
        FROM DiggerMobile
    
        WHERE digger = @digger and datePlaced is null and dateSkipped is null
    
        order by bay, id        

END ELSE
SELECT id as digID, digger, bay, unitNumber, destination, code, item, maxLen, cast(pieces as integer) as pieces,
    status, cast(wholeUnit as integer) as wholeUnit,
    cast(noSubstituteUnits as integer) as noSubstituteUnits, originalUnitNumber, isSub
    FROM DiggerMobile
    
    WHERE digger = @digger and datePlaced is null and dateSkipped is null
    
    order by bay, id
GO
