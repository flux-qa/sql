USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[TripToShipped]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[TripToShipped]
@tripNo integer = 1095542

-- Changed 12/18/18 To Compute UMShipped from lengths
as


declare @tripDate datetime,
@tripNumber integer

update unitLengths set qtyshipped = 0 where qtyShipped is null


select @tripDate = StartTime, @tripNumber = tripNumber
from TRIPCALENDAR where ID = @TripNo

exec CreateContractorInstructions

-- 1st Update OrderLines - UMShipped and DateShipped
Update ORDERLINES set dateShipped = @tripDate, shippedFlag = 1,
shipDateOrDesignStatus = case when O.originalShipTo_RID = O.ob_Customers_RID then convert(varchar(10), @tripDate, 7)
    else shipDateOrDesignStatus end,
UMShipped = ROUND(Z.LFStock * 1.0 / I.LFperUM,0)
from ORDERLINES L inner join Items I on L.ob_Items_RID = I.ID
inner join Orders O on L.ob_Orders_RID = O.ID
inner join (select ps_OrderLines_RID as ID,
    sum(L.length * L.qtyOnHand) as LFStock from UNITS U inner join UnitLengths L on L.ob_Units_RID = U.ID
    group by ps_OrderLines_RID) as Z on L.ID = Z.ID 
WHERE L.tripNumber = @tripNumber AND Z.LFStock > 0

-- update Orders
Update ORDERS set dateShipped = @tripDate, tripNumber = @tripNumber
from  ORDERS O inner join ORDERLINES L  ON L.ob_Orders_RID = O.ID
WHERE L.tripNumber = @tripNumber

-- Reduce the Stock and Available 
Update ITEMS set UMStock = UMStock - Z.UMShipped, 
	UMUnShipped = UMUnShipped- Z.UMShipped,
	UMAvailableString = RTRIM(REPLACE(CONVERT(varchar(20), (CAST(UMAvailable AS money)), 1), '.00', '') 
+ ' ' + UM)
	from ITEMS I inner join (select L.ob_Items_RID as ID, sum(UMShipped) as UMShipped
		from ORDERLINES L WHERE L.tripNumber = @tripNumber group by L.ob_Items_RID) as Z on Z.ID = I.ID

-- Update the Unit Lengths 
update UNITLENGTHS set qtyShipped = qtyOnHand, qtyOnHand = 0
from UNITLENGTHS UL inner join UNITS U on UL.ob_Units_RID = U.ID
inner join ORDERLINES L on U.ps_OrderLines_RID = L.ID
WHERE L.tripNumber = @tripNumber and UL.qtyshipped = 0 AND UL.qtyOnHand > 0

-- UPDATE UNITS AND GENERATE TALLY STRING
update UNITS 
set UMShipped = U.UMStock, piecesShipped = U.piecesStock,
    UMStock = 0, LFStock = 0, piecesStock = 0, dateShipped = @tripDate,
    tallyString = name_csv

from UNITS U
--inner join ORDERUNITS OU on OU.ps_Units_RID = U.ID
inner join ORDERLINES L on U.ps_OrderLines_RID = L.ID
inner  join (select ob_units_RID, stuff((
        select ', ' + ltrim(rtrim(cast(case when qtyShipped > 0 then qtyShipped else qtyOnHand end as char(5)))) + 
        '/'  + cast(length as char(2)) + ''''
        from UNITLENGTHS t
        where t.ob_Units_RID = UNITLENGTHS.ob_Units_RID
        order by t.[length]
        for xml path ('')
    ),1,2,'') as name_csv
from UNITLENGTHS
where ob_Units_RID in (select U.ID
    from UNITS U inner join ORDERLINES L on U.ps_OrderLines_RID = L.ID
    inner join TRIPCALENDAR T on L.tripNumber = T.tripNumber
    where T.ID = @tripno
)
--= @unit
group by ob_Units_RID ) as Z on U.ID = Z.ob_units_RID
WHERE L.tripNumber = @tripNumber and U.UMShipped = 0


/*
-- IF CONSIGNMENT UNIT ADD TO CONSIGNMENT LOG
INSERT INTO [dbo].[ConsignmentTransactions]([ID], [BASVERSION], [BASTIMESTAMP], 
[cost], [pieces], [qtyUM], 
[action], [description], [dateEntered], 
[ps_Units_REN], [ps_Units_RID], [ps_Units_RMA], 
[ps_Items_REN], [ps_Items_RID], [ps_Items_RMA])
 
 select next value for bas_IDGEN_SEQ, 1, getdate(),
 U.actualCost, U.piecesShipped, U.UMShipped,  
 L.orderLineForDisplay, 'Trip: ' + LTRIM(RTRIM(cast(tripNumber as varchar(6)))) + ' Consignment Unit: ' + cast(U.unit as char(7)),
 getdate(),
 'Units', U.ID, null,
 'Items', U.ob_Items_RID, null
 
 from Units U inner join OrderLines L on U.ps_OrderLines_RID = L.ID 
 where L.tripNumber = @tripNumber and U.consignmentFlag = 1
 */
GO
