USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[TestRest]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[TestRest]

@searchField varchar(max) = ''

as

select top 50
id, name, city, state, zip, left(fieldRep,2) as rep
from Customers
where name like '%' + rtrim(@searchField) + '%' and active = 'A'
order by name
GO
