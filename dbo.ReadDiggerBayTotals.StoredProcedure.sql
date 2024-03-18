USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadDiggerBayTotals]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadDiggerBayTotals]

as

delete from DiggerBayTotals 
insert into DiggerBayTotals (ID, BASVERSION, BASTIMESTAMP,
    digger, bay, noDigs, noWhole, noSubs)


select NEXT VALUE FOR mySEQ, 1, getdate(), digger, bay, nodigs, nowhole, nosubs
from (select D.digger, D.bay, 
    count(*) as noDigs, sum(wholeUnit) as noWhole, 
    sum(case when noSubs = 0 then 0 else 1 end) as noSubs from diggerview D
    
-- EITHER THERE IS NO DiggerOneBay RECORD THAT IS NOT COMPLETE
-- OR THERE IS NO DiggerOneBay RECORD
left outer join (select distinct digger, bay, unitNumber
    from DiggerOneBay where completeFlag = 0) as DOBC 
        on D.digger = DOBC.digger and D.bay = DOBC.bay and D.unit = DOBC.unitNumber
        
left outer join (select distinct digger, bay, unitNumber
    from DiggerOneBay) as DOB 
        on D.digger = DOB.digger and D.bay = DOB.bay and D.unit = DOB.unitNumber        
    where DOB.digger is null OR DOBC.digger is not null
    
    
    group by D.digger, D.bay) as Z
GO
