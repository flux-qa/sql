USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateHandleTablesALL]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateHandleTablesALL]

@designDate     date = '02/02/2024',
@drillNumber    integer = 1

as 

declare @drillID integer

select @drillID = ID from CADDrills 
    where designDate = @designDate and drillNumber = @drillNumber
    
exec CreateHandleCustomer @drillID
exec CreateHandleCustomerOrders @drillID
exec CreateHandleOrderTargets @drillID
exec CreateHandleOrderTransactions @drillID
GO
