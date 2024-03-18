USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateDistinctUnitLengths]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateDistinctUnitLengths]
-- Finds the Item for the selectetd unit then all of the lengths

--
-- Last Change 11/06/17
--
@Item integer

as


delete from DistinctUnitLengths;


with w as (select distinct length
    from UNITLENGTHS L 
    inner join UNITS U on L.ob_Units_RID = U.ID
    where U.ob_Items_RID = @Item
    and (dateadd(dd, -730, getDate()) < U.dateReceived or dateadd(dd, -730, getDate()) < U.dateEntered)
    )

insert into DistinctUnitLengths (ID, BASVERSION, BASTIMESTAMP, length)
select length, 1, getDate(), length from w
GO
