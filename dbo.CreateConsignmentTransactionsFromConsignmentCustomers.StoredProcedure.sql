USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateConsignmentTransactionsFromConsignmentCustomers]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateConsignmentTransactionsFromConsignmentCustomers]
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
	@cost					decimal(8,2),


    @consignmentUM          integer


  
-- 1st find consignment orders
DECLARE myCursor CURSOR FAST_FORWARD  FOR  

SELECT L.ID as orderLineID, I.ID as itemID, C.ID as customerID,
L.orderLineForDisplay, O.dateEntered, C.name, L.UMOrdered, L.materialCost
	from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID 
	inner join Items I on L.ob_Items_RID = I.ID 
	inner join Customers C on O.originalShipTo_RID = C.ID 
	where dateAdd(dd, -5, getdate()) < O.dateEntered 
		and C.reloadCustomer = 1 and (I.ID < 10000 or I.ID > 10010)
		and L.dateConsignmentProcessed is null

OPEN myCursor 
FETCH NEXT FROM mycursor INTO @orderLineID, @itemID, @customerID, @orderLineForDisplay, @dateEntered,
    @customerName, @UMOrdered, @cost
WHILE @@FETCH_STATUS = 0  
BEGIN
    -- READ CONSIGNMENTUM FROM ITEM FILE
    select @consignmentUM = consignmentUM from Items where ID = @itemID
	
	-- IF ENOUGH CONSIGNMENT UM FOR ORDER, LOG THE TRANSACTION AND DECREMENT THE CONSIGNMENT UM
	IF @UMOrdered <= @consignmentUM BEGIN
		INSERT INTO ConsignmentTransactions([ID], [BASVERSION], [BASTIMESTAMP], 
			[cost], [pieces], [qtyUM], [action],   [dateEntered], 
			[description], [consignmentUM], [qtySold], [qtyPurchased], 
			[ps_Items_REN], [ps_Items_RID], [ps_Items_RMA], 
			[ps_Customers_REN], [ps_Customers_RID], [ps_Customers_RMA], 
			[ps_OrderLines_REN], [ps_OrderLines_RID], [ps_OrderLines_RMA]) 
			
		select next value for mySeq, 1, getdate(),
			@cost, @UMOrdered, @UMOrdered, 'To Consignment', @dateEntered,
			'Consignment Order: ' + @orderLineForDisplay, @consignmentUM, 0, 0,
			'Items', @itemID, null,
			'Customers', @customerID, null,
			'OrderLines', @orderLineID, null
			
		Update Items SET consignmentUM = consignmentUM - @UMOrdered WHERE ID = @itemID
	
	END	ELSE BEGIN -- IF @UMOrdered <= @consignmentUM
	
			
			-- IF ANY CONSIGNMENT QTY THEN CREATE TRANSACTION FOR THE CONSIGNMENT QTY
		IF @consignmentUM > 0 BEGIN
				INSERT INTO ConsignmentTransactions([ID], [BASVERSION], [BASTIMESTAMP], 
				[cost], [pieces], [qtyUM], [action],   [dateEntered], 
				[description], [consignmentUM], [qtySold], [qtyPurchased], 
				[ps_Items_REN], [ps_Items_RID], [ps_Items_RMA], 
				[ps_Customers_REN], [ps_Customers_RID], [ps_Customers_RMA], 
				[ps_OrderLines_REN], [ps_OrderLines_RID], [ps_OrderLines_RMA]) 
				
			select next value for mySeq, 1, getdate(),
				@cost, @consignmentUM, @consignmentUM, 'Partial To Consignment', @dateEntered,
				'Partial Consignment Order: ' + @orderLineForDisplay, @consignmentUM, 0, 0,
				'Items', @itemID, null,
				'Customers', @customerID, null,
				'OrderLines', @orderLineID, null
			END -- IF @ConsignmentUM > 0
			
			-- CREATE TRANSACTION FOR QTY THEY PURCHASED
			INSERT INTO ConsignmentTransactions([ID], [BASVERSION], [BASTIMESTAMP], 
			[cost], [pieces], [qtyUM], [action],   [dateEntered], 
			[description], [consignmentUM], [qtySold], [qtyPurchased], 
			[ps_Items_REN], [ps_Items_RID], [ps_Items_RMA], 
			[ps_Customers_REN], [ps_Customers_RID], [ps_Customers_RMA], 
			[ps_OrderLines_REN], [ps_OrderLines_RID], [ps_OrderLines_RMA]) 
			
		select next value for mySeq, 1, getdate(),
			@cost,  @UMOrdered - @consignmentUM, @UMOrdered - @consignmentUM, 'SOLD STOCK', @dateEntered,
			'Sold Stock To Consignment Order: ' + @orderLineForDisplay, @consignmentUM,  @UMOrdered - @consignmentUM, 0,
			'Items', @itemID, null,
			'Customers', @customerID, null,
			'OrderLines', @orderLineID, null			
		
		Update Items SET consignmentUM = 0 WHERE ID = @itemID
		
		END -- ELSE
		
	-- SET THE DATE COMMITTMENT UPDATED SO NOT RUN AGAIN 
	UPDATE OrderLines set DateConsignmentProcessed = getdate() where ID = @OrderLineID


    FETCH NEXT FROM mycursor INTO @orderLineID, @itemID, @customerID, @orderLineForDisplay, @dateEntered,
        @customerName, @UMOrdered, @cost
END
CLOSE mycursor  
DEALLOCATE mycursor 

END
GO
