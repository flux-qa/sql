USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ProcessTerminalPO]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ProcessTerminalPO]

@PONumber           integer = 40497


as

declare @lineID             integer
declare @itemID             integer
declare @quantityOrdered    integer

DECLARE myCursor CURSOR FOR 
    SELECT L.ID, ob_Items_RID as itemID, quantityOrdered 
    from PurchaseLines L inner join PurchaseOrders O on L.ob_PurchaseOrders_RID = O.ID
    where O.poNumber = @PONumber

OPEN myCursor 
FETCH NEXT FROM mycursor INTO @lineID, @itemID, @quantityOrdered 

WHILE @@FETCH_STATUS = 0  
BEGIN 


    -- AS LONG AS THERE IS A BALANCE FIND TERMINAL COMMITMENT TO APPLY IT TO
    WHILE @quantityOrdered > 0
        begin
            print @quantityOrdered
            exec ProcessTerminalPOOneLine @lineID, @itemID, @quantityOrdered OUT
        end
    
    FETCH NEXT FROM mycursor INTO @lineID, @itemID, @quantityOrdered
END 

CLOSE mycursor  
DEALLOCATE mycursor
GO
