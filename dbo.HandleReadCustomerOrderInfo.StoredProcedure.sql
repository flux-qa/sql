USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[HandleReadCustomerOrderInfo]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HandleReadCustomerOrderInfo]

@orderLinesID   integer = 14738218,
@designDate     date = '02/06/24',
@drillNumber    integer = 1

as

-- last change 02/06/24

declare @drillID        integer


select @drillID = ID from CADDrills where designDate = @designDate and drillNumber = @drillNumber

select HCO.ID as handleCustomerOrdersID, EastOrWest, code, item, UMOrdered, UM, orderNumberForDisplay, rowNumber, tank, handlingArea, 
    orderDesignerComments, orderDesignerComments, customerDesignComments,
    customerName, customerAdd1, customerAdd2, customerCity, customerState, customerZip 

    from HandleCustomerOrders HCO  join HandleCustomer HC on HCO.ob_HandleCustomer_RID = HC.ID --and HCO.drillID = HC.drillID
    
    where HCO.drillID = @drillID and HCO.ob_OrderLines_RID = @orderLinesID
GO
