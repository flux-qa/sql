USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ProcessCommittmentOrderLineTrigger]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ProcessCommittmentOrderLineTrigger]
@orderLineID    integer


-- last change 06/03/2022 -- changed consignment adjustment to negative when purchased from consignment

as

declare 
       @orderNumber             integer,
       @lineNumber              integer,
       @oldCode                 varchar(5),
       @consignmentCustomer     integer,
       @qtyOrdered              integer,
       @startingConsignmentQty  integer,
       @consignmentAdjustment   integer = 0,       
       @UMAvailable             integer,
       @comment                 varchar(2000) = '',
       @qtyBought               integer = 0,
       @qtySold                 integer = 0
       
declare
       @soldFromStock           integer
       
-- READ THE DATA
select @orderNumber         = O.orderNumber,
    @lineNumber             = L.lineNumber,
    @oldcode                = I.oldCode,
    @consignmentCustomer    = C.reloadCustomer,
    @qtyOrdered             = L.UMOrdered,
    @startingConsignmentQty = I.consignmentUM,
    @UMAvailable            = I.UMAvailable,
    
    @soldFromStock  = case when L.WRD = 'W' and L.ps_PurchaseLines_RID is NULL then 1
    else 0 end
      
    from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Items I on L.ob_Items_RID = I.ID
    inner join Customers C on O.originalShipTo_RID = C.ID
    where L.ID = @orderLineID
    
-- IF CONSIGNMENT CUSTOMER SEE IF WE HAVE ENOUGH CONSIGNMENT QTY
-- IF SO, JUST REDUCE THE CONSIGNMENT QTY BY QTY ORDERED
-- IF NOT, SELL (QTY ORDERED - CONSIGNMENT QTY) AND SET CONSIGNMENT QTY TO ZERO
IF @consignmentCustomer = 1 BEGIN
    IF @qtyOrdered <= @startingConsignmentQty BEGIN
        -- TO DO!  Decrement the Item ConsignmentUM by @qtyOrdered
        set @comment = 'Consignment Sale'
        set @consignmentAdjustment = -1 * @qtyOrdered
        END
    ELSE IF @qtyOrdered > @startingConsignmentQty BEGIN
        set @qtySold = @qtyOrdered - @startingConsignmentQty
        set @consignmentAdjustment = -1 * @startingConsignmentQty 
        set @comment = 'Consignment Sale - Had to buy some ALC Stock'
        -- TO DO!  set Item consignmentUM = 0
        END        
    END -- IF @consignmentCustomer = 1

-- IF NOT A CONSIGNMENT CUSTOMER AND A WAREHOUSE ORDER 
-- AND ORDER > UMAVAIL AND HAVE CONSIGNMENT STOCK
-- THEN ALC HAS TO PURCHASE (BUY) SOME STOCK FROM CONSIGNMENT
IF @consignmentCustomer = 0 AND 
    @soldFromStock = 1 AND
    @qtyOrdered > @UMAvailable - @startingConsignmentQty AND
    @startingConsignmentQty <= @UMAvailable AND
    @startingConsignmentQty > 0 BEGIN
    -- HANDLE WHEN CONSIGNMENT UM > UMAVAILABLE
    
    set @qtyBought = CASE when @startingConsignmentQty > @UMAvailable then @qtyOrdered 
        else @qtyOrdered - (@UMAvailable - @startingConsignmentQty) end
    set @consignmentAdjustment = -1 * @qtyBought
    set @comment = 'Purchase Consignment'
    -- TO DO!  Decrement the Item ConsignmentUM by @qtyBought
    END -- IF @consignmentCustomer = 0
   
-- ERROR IF CONSIGNMENT UM > UMAVAILABLE
-- ERROR IF CONSIGNMENT UM < 0
IF @startingConsignmentQty > @UMAvailable
    set @comment = RTRIM(@comment) + ' --> ERROR! Consignment UM > UM Available'



IF @comment <> ''    
    INSERT INTO [dbo].[ConsignmentOrderLineAudit]( [orderNumber], [lineNumber], 
    [oldCode], [consignmentCustomer], [qtyOrdered], [startingConsignmentQty], 
    [consignmentAdjustment], [comment], [UMAvailable], 
    [qtyBought], [qtySold], orderLineID) 
        VALUES(@orderNumber, @lineNumber, @oldCode, @consignmentCustomer,
        @qtyOrdered, @startingConsignmentQty, @consignmentAdjustment, @comment, 
        @UMAvailable, @qtyBought, @qtySold, @orderLineID)
GO
