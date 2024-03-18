USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[newSP]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[newSP] 
as
SELECT top 40
    name,
    modify_date,
    create_date
FROM sys.procedures
order by modify_date desc
GO
