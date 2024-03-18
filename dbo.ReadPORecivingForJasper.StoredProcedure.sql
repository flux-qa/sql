USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadPORecivingForJasper]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadPORecivingForJasper]
@POID integer = 38081

as

select P.PONumber, V.name as vendor, I.internalDescription as item, 
L.quantityOrdered, L.UM, L.cost, L.costPerString, L.costper, L.dateReceived, 
Z.length, Z.lengthString, Z.pieces, round(Z.pieces * Z.length / I.LFPerUM,0) as UMReceived,
Y.noUnits


from PurchaseOrders P inner join PurchaseLines L on P.ID = L.ob_PurchaseOrders_RID
inner join Items I on I.ID = L.ob_Items_RID
--inner join Units U on U.ps_PurchaseLines_RID = L.ID
inner join Vendors V on V.ID = P.ob_Vendors_RID
inner join (select U.ps_PurchaseLines_RID as POLineID, length, lengthString, sum( originalQty) as pieces
    from Units U inner join UnitLengths L on U.ID = L.ob_Units_RID
     group by U.ps_PurchaseLines_RID, length, lengthString) as Z on Z.POLineID = L.ID
     
inner join (select U.ps_PurchaseLines_RID as POLineID, count (distinct U.ID) as noUnits
    from Units U inner join UnitLengths L on U.ID = L.ob_Units_RID
     group by U.ps_PurchaseLines_RID) as Y on Y.POLineID = L.ID     

where P.ID = @POID

order by L.lineNumber, Z.length
GO
