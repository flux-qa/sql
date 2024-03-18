USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateTempTargetTagsWholeUnits]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateTempTargetTagsWholeUnits]

@designDate		date = '11/15/2022',
@drillNumber	integer	= 1

AS

delete from TempTargetTags
;

with w as (
select distinct bay as area, D.diggerNumber, 
    U.location ,
	L.tank, U.Unit, left(C.name,11) as name, LEFT(C.city,20) as city, 
	left(O.PONumber,20) as PONumber, L.orderLineForDisplay,  '' as item
    
    from ORDERUNITS OU
    inner join ORDERLINES L on OU.ob_OrderLines_RID = L.ID
    inner join ORDERS O on L.ob_Orders_RID = O.ID
    inner join CUSTOMERS C on O.ob_Customers_RID = C.ID

    inner join UNITS U on OU.ps_Units_RID = U.ID
    inner join ITEMS I on U.ob_Items_RID = I.ID
    inner join CADDRILLS CD on CD.ID = OU.ps_CADDrills_RID
   
    left outer join DIGGERBAYLINK D on D.bay = Left(U.location,1)
     left outer join DIGGERBAYSTRING S on D.diggerNumber = S.ID
    
    Where CD.designDate = @designDate and CD.drillNumber = @drillNumber
    	and (L.wholeUnits = 1 OR ou.wholeUnitAssigned = 1) 
		and C.ID <> 6456 -- SKIP NEWTECH	
	)
		


insert into TempTargetTags (ID, BASVERSION, BASTIMESTAMP,
	westEast, rowno, handle, tank, unit, name, city, PONumber, orderLineForDisplay, item)
		
select next value for mySeq, 1, getdate(),
	0, row_number() over (Order by diggerNumber, location) as rowno,
	'', tank, unit, name, city, PONumber, orderLineForDisplay, item 
	from W
GO
