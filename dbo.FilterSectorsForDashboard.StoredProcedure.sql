USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[FilterSectorsForDashboard]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[FilterSectorsForDashboard]
@tripID integer,
@fieldRep char(3)

as 

declare @maxID integer

select @maxID = isNull(max(ID),0) FROM FILTEREDSECTORSFORDASHBOARD

delete from FILTEREDSECTORSFORDASHBOARD
    where fieldRep = @FieldRep

INSERT INTO FILTEREDSECTORSFORDASHBOARD ([ID], [BASVERSION], [BASTIMESTAMP], 
fieldRep, sector_REN, sector_RID)

select @MaxID + row_number() over (order by sector), 1, getDate(), @fieldRep, 'Sectors', sector
from (select distinct C.ps_Sector_RID as sector
    from TRIPCALENDAR T inner join TRIPSTOPS TS on TS.ob_TripCalendar_RID = T.ID
    inner join CUSTOMERS C on TS.ps_Customers_RID = C.ID
    where T.ID = @tripID) as Z
GO
