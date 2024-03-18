USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateHandleCustomerOrders]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateHandleCustomerOrders]
@drillID integer  = 14729257

as

-- last change 02/04/24

DELETE FROM HandleCustomerOrders where drillID = @drillID

INSERT INTO [dbo].[HandleCustomerOrders]([ID], [BASVERSION], [BASTIMESTAMP], 
[EastOrWest], [code], item, [UMOrdered], [UM], [orderNumberForDisplay], [tank],
[rowNumber],  [handlingArea], handleComplete,
orderDesignComments, orderDesignerComments,
[ob_OrderLines_REN], [ob_OrderLines_RID],
[ob_HandleCustomer_REN], [ob_HandleCustomer_RID], [ob_HandleCustomer_RMA], 
 [ps_Items_REN], [ps_Items_RID],   [drillID]) 

select next value for mySEQ, 1, getdate(),
    eastOrWest, code, item, UMOrdered, UM, orderLineForDisplay, tank,
    rownumber, handleLocation, 0, designComments, designerComments,
    'OrderLines', LID, 'HandleCustomer', HCID, 'om_HandleCustomerOrders',
    'Items', itemID, drillID
    from (select distinct case when N.west4East0 = 0 then 'E' else 'W' end as eastOrWest, 
        T.code, T.item, T.UMOrdered, T.UM, T.orderLineForDisplay, L.tank,
        N.rowNumber, N.handleLocation, L.designComments, L.designerComments,  
        L.ID as LID, HC.ID as HCID, T.itemID, T.drillID
            from CADTransactionView T inner join HandleCustomer HC on T.customerID = HC.customerID and T.drillID = HC.drillID
            inner join NewHandleOrders N on N.ps_OrderLines_RID = T.orderLineID
            inner join OrderLines L on T.orderLineID = L.ID
            where T.drillID = @drillID) as Z
GO
