USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ProcessTerminalPOOneLine]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ProcessTerminalPOOneLine]

@lineID             integer,
@itemID             integer,
@quantityOrdered    integer out

as

declare @noRows     integer
declare @commitQty  integer
declare @TCIBalance integer
declare @TCIID      integer
declare @TIID       integer
declare @ID         integer

-- FIND THE OLDEST TERMINAL ITEM COMMITMENT WHERE THERE IS A POSITIVE BALANCE.
select TOP 1 @TCIBalance = TCI.balance, @TCIID = TCI.ID, @TIID = TI.ID
    from PurchaseLines L inner join TerminalItems TI on L.ob_Items_RID = TI.ps_Item_RID
    inner join TerminalCommitmentItems TCI on TCI.ps_TerminalItems_RID = TI.ID
    inner join TerminalCommitments TC on TCI.ob_TerminalCommitments_RID = TC.ID
    where L.ID = @lineID and TCI.balance > 0 
    order by TC.forPeriod
 
-- IF BALANCE FOUND, THEN COMPUTE THE MIN OF BALANCE OR PO QTY AND CREATE TERMINAL SHIPMENT
IF @TCIBalance is not null
    begin
        set @commitQty = case when @TCIBalance > @quantityOrdered then @quantityOrdered else @TCIBalance end 
        set @quantityOrdered = @quantityOrdered - @commitQty
        set @ID = next value for BAS_IDGEN_SEQ

-- UPDATE BALANCE IN TERMINAL COMMITMENT ITEMS BY THE COMMITTED QTY
update TerminalCommitmentItems 
    set quantityShipped = quantityShipped + @commitQty,
    balance = balance - @commitQty 
    where ID = @TCIID

-- UPDATE THE TERMINAL ITEM
Update TerminalItems set totalReceived = totalReceived + @commitQty,
    balance = balance - @commitQty
    where ID = @TIID

INSERT INTO [TerminalShipments]([ID], [BASVERSION], [BASTIMESTAMP], 
[ob_TerminalItems_REN], [ob_TerminalItems_RID], [ob_TerminalItems_RMA], 
[entryDate], [quantity], [ps_PurchaseLines_REN], [ps_PurchaseLines_RID], [ps_PurchaseLines_RMA], 
[ps_TerminalCommitmentItems_REN], [ps_TerminalCommitmentItems_RID], [ps_TerminalCommitmentItems_RMA]) 
   
select  @ID, 1, getdate(),
        'TerminalItems', TI.ID, 'om_TerminalShipments',
        getDate(), @commitQty, 'PurchaseLines', @lineID, null,
        'TerminalCommitmentItems', TCI.ID, 'pm_TerminalShipments'
    
        from PurchaseLines L inner join TerminalItems TI on L.ob_Items_RID = TI.ps_Item_RID
        inner join TerminalCommitmentItems TCI on TCI.ps_TerminalItems_RID = TI.ID
        inner join TerminalCommitments TC on TCI.ob_TerminalCommitments_RID = TC.ID
        where L.ID = @lineID and TCI.ID = @TCIID
        
        -- RETURN TO CALLING PROCEDURE TO BE CALLED AGAIN

        return
    end
    
    
-- IF THIS LINE REACHED, THEN THERE IS NO TERMINAL COMMITMENT ITEM WITH A QTY    
set @quantityOrdered = 0
GO
