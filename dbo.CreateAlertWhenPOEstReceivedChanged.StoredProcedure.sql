USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateAlertWhenPOEstReceivedChanged]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateAlertWhenPOEstReceivedChanged]


@PONumber integer = 40998
   
as

INSERT INTO [dbo].[ALERTS]([ID], [BASVERSION], [BASTIMESTAMP], 
    [isArchived], [objectID], [forUser], [alertType], [fromProcess], [processName], 
    [objectName], [comment], [dateArchived], [dateCreated])     
  
    
select next Value For BAS_IDGEN_SEQ, 1, getDate(),
    0, P.ID, 
     left(c.fieldRep,2),
     'Est. Rcvd Date Changed', 'PO Updated', 'EditOrderFromAlert', 'Orders', 
     'NEW Est. Rcvd Date:  ' + rtrim(convert(char(12), P.estReceivedDate, 1)) + ' for: ' + 
        rtrim(C.name) + ' Order#: ' + cast(O.orderNumber as char(6)) + '-' + rtrim(cast(L.lineNumber as char(2))) + ' ' + I.oldcode + ' ' + I.internalDescription,
     null, getdate() 

    from PurchaseOrders P inner join PurchaseLines PL on PL.ob_PurchaseOrders_RID = P.ID
    inner join Items I on PL.ob_Items_RID = I.ID
    inner join OrderLines L on L.ps_PurchaseLines_RID = PL.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID

    where P.PONumber = @PONumber
GO
