USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[OLToWP]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create procedure [dbo].[OLToWP]
@id integer

as

update orderlines set designStatus = 'W/P' where id = @id
GO
