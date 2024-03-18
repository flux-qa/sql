USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ToggleDateDug]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ToggleDateDug]
@digID      integer
as
Update DiggerMobile 
    set dateDug = case when dateDug IS NULL then getdate() else null end  
    where ID = @digID
GO
