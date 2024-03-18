USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadCustomersAndLastSaleDate]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create Procedure [dbo].[ReadCustomersAndLastSaleDate]

as

select ID, name, city, state, left(fieldRep,2) as fieldRep, phone, Z.lastOrder
from Customers C left outer join (select ob_Customers_RID, max(dateEntered) as lastOrder 
    from Orders group by ob_Customers_RID) as Z on C.ID = Z.ob_Customers_RID
where C.active = 'A'
order by C.name, C.city
GO
