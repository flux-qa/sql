USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CheckForShippedOrderLines]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE   PROCEDURE [dbo].[CheckForShippedOrderLines]

@tripno     integer,
@custname   varchar(100) OUTPUT

as

select top 1 @custname = RTRIM(C.name) + ' --> ' + L.orderLineForDisplay

    from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    
    where L.tripNumber = @tripNo and L.dateShipped IS NOT NULL
    
set @custname = ISNULL(@custname,'')
GO
