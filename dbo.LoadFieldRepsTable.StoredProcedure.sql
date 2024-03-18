USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[LoadFieldRepsTable]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[LoadFieldRepsTable]
as

delete from FIELDREPS

insert into FIELDREPS (ID, BASTIMESTAMP, fieldRep)


select row_number()   over (order by fieldRep),  getdate(), fieldRep
from (
select distinct fieldRep
from CUSTOMERS) as C
GO
