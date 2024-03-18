USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadDiggerTotals]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadDiggerTotals]

-- last change 01/06/24

as

delete from DiggerTotals

insert into DiggerTotals (ID, BASVERSION, BASTIMESTAMP,
    digger, noBays, noAisles, noDigs, noWhole, noSubs)
    
select NEXT VALUE FOR mySEQ, 1, getdate(),
    digger, noBays, noAisles, noDigs, noWhole, noSubs

from (select D.digger, count(distinct D.bay) as noBays, 
count(distinct left(D.bay,1)) as noAisles,
count(*) as noDigs, sum(wholeUnit) as noWhole, 
sum(case when noSubs = 0 then 0 else 1 end) as noSubs 
from Diggerview D 

-- EITHER THERE IS NO DiggerOneBay RECORD THAT IS NOT COMPLETE
-- OR THERE IS NO DiggerOneBay RECORD
left outer join (select distinct digger, bay, unitNumber, designDate, drillNumber
    from DiggerOneBay where completeFlag = 0) as DOBC 
        on D.digger = DOBC.digger and D.unit = DOBC.unitNumber and D.designDate = DOBC.designDate and D.drillNumber = DOBC.drillNumber
        
left outer join (select distinct digger, bay, unitNumber, designDate, drillNumber
    from DiggerOneBay) as DOB 
        on D.digger = DOB.digger and D.unit = DOB.unitNumber and D.designDate = DOB.designDate and D.drillNumber = DOB.drillNumber       

where DOB.digger is null OR DOBC.digger is not null   
group by D.digger) as Z
GO
