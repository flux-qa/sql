USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[Ship1Order]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Ship1Order]

@orderID integer = 123

as

SET NOCOUNT ON
    
declare @dateShipped date
    
select @dateShipped = dateShipped from Orders where ID = @orderID
if @dateShipped IS NOT NULL
    return 0
    

-- 1st Update OrderLines - UMShipped and DateShipped
Update ORDERLINES set dateShipped = getDate(), shipDateOrDesignStatus = convert(varchar(10), getdate(), 7),
UMShipped = Z.UMStock, shippedFlag = 1
from ORDERLINES L inner join (select ps_OrderLines_RID as ID,
    sum(U.UMStock) as UMStock from UNITS U 
    group by ps_OrderLines_RID) as Z on L.ID = Z.ID 
WHERE L.ob_Orders_RID = @OrderID

-- Dont forget to ship the Freight and Misc.
Update ORDERLINES set dateShipped = getDate(), shipDateOrDesignStatus = convert(varchar(10), getdate(), 7),
UMShipped = 1, shippedFlag = 1
from ORDERLINES L  
WHERE L.ob_Orders_RID = @OrderID AND (L.ob_Items_RID > 9999 and L.ob_Items_RID < 10011)


-- update Orders
Update ORDERS set dateShipped = getDate()
from  ORDERS O inner join ORDERLINES L  ON L.ob_Orders_RID = O.ID
WHERE O.ID = @orderID

-- Reduce the Stock and Available 
Update ITEMS set UMStock = UMStock - Z.UMShipped, 
	UMUnShipped = UMUnShipped- Z.UMShipped,
	UMAvailableString = RTRIM(REPLACE(CONVERT(varchar(20), (CAST(UMAvailable AS money)), 1), '.00', '') 
+ ' ' + UM)
	from ITEMS I inner join (select L.ob_Items_RID as ID, sum(UMShipped) as UMShipped
		from ORDERLINES L WHERE L.ob_Orders_RID = @orderID group by L.ob_Items_RID) as Z on Z.ID = I.ID

-- Update the Unit Lengths 
update UNITLENGTHS set qtyShipped = qtyOnHand, qtyOnHand = 0
from UNITLENGTHS UL inner join UNITS U on UL.ob_Units_RID = U.ID
inner join ORDERLINES L on U.ps_OrderLines_RID = L.ID
WHERE L.ob_Orders_RID = @orderID and UL.qtyOnHand > 0

-- UPDATE UNITS AND GENERATE TALLY STRING
update UNITS 
set UMShipped = U.UMStock, piecesShipped = U.piecesStock,
    UMStock = 0, LFStock = 0, piecesStock = 0, dateShipped = getDate(),
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
    where L.ob_Orders_RID = @orderID
)
--= @unit
group by ob_Units_RID ) as Z on U.ID = Z.ob_units_RID
WHERE L.ob_Orders_RID = @orderID and U.UMShipped = 0

/*
-- IF CONSIGNMENT UNIT ADD TO CONSIGNMENT LOG
INSERT INTO [dbo].[ConsignmentTransactions]([ID], [BASVERSION], [BASTIMESTAMP], 
[cost], [pieces], [qtyUM], 
[action], [description], [dateEntered], 
[ps_Units_REN], [ps_Units_RID], [ps_Units_RMA], 
[ps_Items_REN], [ps_Items_RID], [ps_Items_RMA])
 
 select next value for bas_IDGEN_SEQ, 1, getdate(),
 U.actualCost, U.piecesShipped, U.UMShipped, 
 L.orderLineForDisplay, 'Shipped Consignment Unit: ' + cast(U.unit as char(7)), getdate(),
 'Units', U.ID, null,
 'Items', U.ob_Items_RID, null
 
 from Units U inner join OrderLines L on U.ps_OrderLines_RID = L.ID 
 where L.ob_Orders_RID = @orderID and U.consignmentFlag = 1
 */
GO
