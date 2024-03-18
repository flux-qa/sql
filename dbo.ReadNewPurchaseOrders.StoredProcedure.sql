USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadNewPurchaseOrders]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadNewPurchaseOrders]
as 

select top 100
V.oldCode as vendorCode, V.name,
P.PONumber, P.dateEntered, P.buyer, isNull(p.comments,'') as comments,
p.mustEnterFreight, P.freight,
P.miscCharges, isNull(P.totalFlatCharge,0) as totalFlatCharge,
 P.subTotal, p.totalBMEs, p.vendorContact,
P.status,  P.terms, P.shipVia, isNull(C.oldCustNo,'') as shipToCode,
P.estRollingDate,P.estReceivedDate, P.revisionNumber, P.FOB

from PURCHASEORDERS P inner join VENDORS V on P.ob_Vendors_RID = V.ID
left outer join customers C on P.ps_Customers_RID = C.ID

order by P.PONumber desc
GO
