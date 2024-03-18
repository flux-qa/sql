USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[testSPSpeed]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create   procedure [dbo].[testSPSpeed] 
@name varchar(50)
as
select count(*) as noCusts from customers where name like @name +'%'
GO
