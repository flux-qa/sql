USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[FindKeywordInProcedure]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[FindKeywordInProcedure]
@keyword varchar(max)

as

set @keyword = '%' + RTRIM(LTRIM(@keyword)) + '%'

SELECT ROUTINE_NAME as name, created, last_Altered as lastChg
FROM INFORMATION_SCHEMA.ROUTINES 
WHERE ROUTINE_DEFINITION LIKE @keyword 
AND ROUTINE_TYPE='PROCEDURE'
ORDER BY ROUTINE_NAME
GO
