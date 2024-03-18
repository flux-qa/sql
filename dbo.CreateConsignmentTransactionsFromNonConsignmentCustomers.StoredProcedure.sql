USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateConsignmentTransactionsFromNonConsignmentCustomers]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateConsignmentTransactionsFromNonConsignmentCustomers]
-- last change 12/04/22 -- compute qtyToPurchase
-- 04/08/23 -- add pocketwood to UMAvailable
AS
BEGIN

  
DECLARE
    @orderLineID            integer,
    @itemID                 integer,
	@customerID				integer,
    @orderLineForDisplay    varchar(11),
    @dateEntered            datetime,
    @customerName           varchar(30),
    @UMOrdered              integer,
	@UMAvailable			integer,
	@cost					decimal(8,2),


    @consignmentUM          integer,
		@qtyToPurchase					integer


DECLARE myCursor2 CURSOR FAST_FORWARD  FOR  

SELECT L.ID as orderLineID, I.ID as itemID, C.ID as customerID,
L.orderLineForDisplay, O.dateEntered, C.name, L.UMOrdered, L.materialCost, I.UMAvailable + I.UMPocketwood
	from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID 
	inner join Items I on L.ob_Items_RID = I.ID 
	inner join Customers C on O.originalShipTo_RID = C.ID 
	where dateAdd(dd, -5, getdate()) < O.dateEntered 
        and I.consignmentUM > I.UMAvailable + I.UMPocketWood
        and I.consignmentUM > 0
		and C.reloadCustomer = 0 
        and (I.ID < 10000 or I.ID > 10010)
		and L.ps_PurchaseLines_RID IS NULL		-- ADDED 11/19/22
		and L.dateConsignmentProcessed is null
	order by L.ID

OPEN myCursor2 
FETCH NEXT FROM mycursor2 INTO @orderLineID, @itemID, @customerID, @orderLineForDisplay, @dateEntered,
    @customerName, @UMOrdered, @cost, @UMAvailable
WHILE @@FETCH_STATUS = 0  
BEGIN

    -- READ CONSIGNMENTUM FROM ITEM FILE
    select @consignmentUM = consignmentUM from Items where ID = @itemID
	
	set @qtyToPurchase = case when @UMAvailable >= @consignmentUM then 0 -- DID NOT NEED TO PURCHASE CONSIGNMENT
		when @consignmentUM - @UMAvailable > @UMOrdered then @UMOrdered -- NEVER PURCHASE MORE THAN ORDERED
		else @consignmentUM - @UMAvailable END-- ELSE PURCHASE THE AMOUNT Short
		
	IF @qtyTOPurchase > @consignmentUM set @qtyToPurchase = @consignmentUM	-- NEVER PURCHASE MORE THAN CONSIGNMENT

	IF @consignmentUM > 0 AND @qtyToPurchase > 0 BEGIN
	
		INSERT INTO ConsignmentTransactions([ID], [BASVERSION], [BASTIMESTAMP], 
			[cost], [pieces], [qtyUM], 
            [action],   [dateEntered], 
			[description], [consignmentUM], [qtySold],
            [qtyPurchased],
			[ps_Items_REN], [ps_Items_RID], [ps_Items_RMA], 
			[ps_Customers_REN], [ps_Customers_RID], [ps_Customers_RMA], 
			[ps_OrderLines_REN], [ps_OrderLines_RID], [ps_OrderLines_RMA]) 
			
		select next value for mySeq, 1, getdate(),
			@cost, @qtyToPurchase, @qtyToPurchase, 
			'Purchase Consignment', @dateEntered,
			'Purchased for Order: ' + @orderLineForDisplay, @consignmentUM, 0,
			@qtyToPurchase,
			'Items', @itemID, null,
			'Customers', @customerID, null,
			'OrderLines', @orderLineID, null
			
		Update Items SET consignmentUM = consignmentUM - @qtyToPurchase WHERE ID = @itemID
		
	END -- IF @consignmentUM > 0

	-- SET THE DATE COMMITTMENT UPDATED SO NOT RUN AGAIN 
	UPDATE OrderLines set DateConsignmentProcessed = getdate() where ID = @OrderLineID


FETCH NEXT FROM mycursor2 INTO @orderLineID, @itemID, @customerID, @orderLineForDisplay, @dateEntered,
	@customerName, @UMOrdered, @cost, @UMAvailable
END
CLOSE mycursor2 
DEALLOCATE mycursor2




END
GO
