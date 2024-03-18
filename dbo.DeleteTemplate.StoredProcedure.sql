USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[DeleteTemplate]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DeleteTemplate]
--
-- 12/22/15
--

@item integer
as
delete from Templates
where ob_Items_RID = @Item
GO
