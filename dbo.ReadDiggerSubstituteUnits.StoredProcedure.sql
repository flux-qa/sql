USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadDiggerSubstituteUnits]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadDiggerSubstituteUnits]

@digID      integer

as

select id, substituteUnit, sourceUnit, 
convert(varchar(10), dateReceived, 1) as dateReceived, 
cast(UMStock as integer) as UMStock,
 orderNumberUnitAssignedTo, bay, cast(sortOrder as integer) as sortOrder, 
 tallyFlag, lengths, bayflag, dateFlag
from DiggerSubstituteUnits
where digID = @digID

order by sortOrder, substituteUnit
GO
