USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CheckForMissingUnits]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CheckForMissingUnits]

@tripno     integer,
@custname   varchar(100) OUTPUT

as

select top 1 @custname = RTRIM(C.name) + ' --> ' + L.orderLineForDisplay

    from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    left outer join Units U on U.ps_OrderLines_RID = L.ID
    where L.tripNumber = @tripNo and U.ID IS NULL and (L.ob_Items_RID < 10000 or L.ob_Items_RID > 10010)
    
set @custname = ISNULL(@custname,'')
GO
