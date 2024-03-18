USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateCreditNumberReport]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateCreditNumberReport]

as

DELETE FROM CREDITNUMBERREPORT

INSERT INTO CREDITNUMBERREPORT(ID, BASVERSION, BASTIMESTAMP,
    sortOrder, customerID, name, address, orderID, orderNumber, dateEntered, estDeliveryDate,
creditNumber, lineID, qtyPriceFormatted, internalDescription) 
select row_number() over (order by L.ID) as ID, 1 , getDate(),

case when O.creditNumber IS null or O.creditNumber = '' then 1 else 2 end as sortOrder, C.ID as customerID, C.name, 
rtrim(C.add1) + ' ' + rtrim(C.city) + ' ' + C.state as address, O.ID as orderID, 
rtrim(cast(O.orderNumber as char(8))) + ' - ' + rtrim(cast(lineNumber as char(4))) as orderNumber, O.dateEntered, 
O.estDeliveryDate, O.creditNumber, L.ID as lineID,
 L.qtyPriceFormatted, I.internalDescription 

from ORDERLINES L inner join ORDERS O on L.ob_Orders_RID = O.ID
inner join CUSTOMERS C on O.ob_Customers_RID = C.ID
inner join ITEMS I on L.ob_Items_RID = I.ID
where L.UMShipped = 0
GO
