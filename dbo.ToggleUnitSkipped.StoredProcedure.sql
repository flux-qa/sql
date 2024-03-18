USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ToggleUnitSkipped]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ToggleUnitSkipped]

@digID  integer

as

-- last change 03/13/24

declare @dateSkipped    datetime,
        @unit           integer
        
select @dateSkipped = dateSkipped, @unit = unitNumber
        from DiggerMobile where ID = @digID
        
-- if unit is null then invalid digid
IF @unit IS NULL
    select 0 as success, 'Invalid Dig ID of ' + cast(@digID as varchar(12)) as message

else begin
    Update DiggerMobile set dateSkipped = case when @dateSkipped is null then getdate() else null end
    where id = @digID

    select 1 as success
    end
GO
