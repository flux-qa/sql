USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ItemAvailability]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ItemAvailability]
@filter     varchar(5) = ''

as

set @filter = RTRIM(@filter) + '%'
select

    oldcode as code, internalDescription as item, UMAvailable as avail
    from Items where UMAvailable > 0 and oldcode like @filter
    order by oldcode
GO
