USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateHandleCustomer]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateHandleCustomer]

@drillID integer  = 14729257

-- last change 02/02/24

as

delete from HandleCustomer where drillID = @drillID

INSERT INTO [dbo].[HandleCustomer]([ID], [BASVERSION], [BASTIMESTAMP], 
customerID, customerName, customerAdd1, customerAdd2, customerCity,
customerState, customerZip, customerDesignComments,
designdate, drillNumber, drillID)

select next value for mySeq, 1, getdate(),
customerID, name, add1, add2, city, state, zip,
designComments, designdate, drillNumber, drillID
from (select DISTINCT T.customerID, T.name, T.add1, T.add2, T.city, 
    T.state, T.zip, T.designComments, T.designDate, 
    T.drillNumber, T.drillID
    from CADTransactionView T
    where T.drillID = @drillID) as Z
GO
