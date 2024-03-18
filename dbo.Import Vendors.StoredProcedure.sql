USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[Import Vendors]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Import Vendors]
as

update ALC.dbo.Items set transitDays = 0, orderDays = 0

Update ALC.dbo.Items set transitDays = [lead Days], 
orderDays = coalesce(V.leadTime,0),
idxAggressiveness = case when [indagg change] > 0 then [indagg change] else idxAggressiveness end
from ALC.dbo.Items I inner join ALC.DBO.ItemLeadTimes L on I.oldCode = L.Item
left outer join Vendors V on L.vendor = V.name

update ALC.dbo.Items set leadTime = TransitDays + orderDays

update ALC.dbo.Items set idxAggressiveness = 2 where leadTime = 0 and idxAggressiveness > 2
update ALC.dbo.Items set safetyStockDays = case when IdxAggressiveness > 4 then round(leadTime / 3.0,0) else 0 end

Update ITEMS
set leadTime = A.leadTime,
daysTransit = A.transitDays,
daysToOrder = A.orderDays, 
safetyStockInDays = A.safetyStockDays, 
idxAgressiveness = A.idxAggressiveness

from ITEMS I inner join ALC.dbo.Items A on I.item = A.item



truncate table VENDORS

INSERT INTO [VENDORS]([ID], [BASVERSION], [BASTIMESTAMP], 
[minBF], [state], [name], [zip], [oldCode], [country], [fax], [city], [add2], 
[add1], [contact], [phone], [email]) 

select recID, 1, getDate(),
v.minBFforOrder, state, name, zip, oldCode, country, fax, city, add2,
add1, contact, phone, email
    from ALC.dbo.Vendors V

delete from VENDORS where name = ''

update VENDORS set fullAddress = rtrim(name) + '<br>' +
rtrim(add1) + '<br>' + rtrim(add2) + '<br>' + rtrim(city) + ' ' + state + ' ' + zip +
'<br>' + country

Update Vendors set leadTime = L.[negotiating days]
from Vendors V inner join ALC.dbo.VendorLeadTimes L on V.name = L.vendor
GO
