USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[TestRestOneRecord]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create procedure [dbo].[TestRestOneRecord]
@customerID     integer

as

select id, name, add1, city, state, zip, left(fieldRep,2) as rep from Customers where ID = @customerID
GO
