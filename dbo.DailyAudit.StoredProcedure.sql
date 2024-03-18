USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[DailyAudit]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DailyAudit]

as

select unitNumber, length, balance, qtyOnHand, drillNumber, OrderNumber, lineNumber, name from (

    select row_Number() over (partition by T.ps_UnitLengths_RID order by T.ID desc) as rowNumber ,    
    T.unitNumber, T.length, T.balance, L.qtyOnHand, D.drillNumber, O.orderNumber, OL.lineNumber, C.name, C.city
    
    from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
    inner join CADDrills D on T.ps_CADDrills_RID = D.ID
    inner join OrderLines OL on T.ps_OrderLines_RID = OL.ID
    inner join Orders O on OL.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID   
    where D.designDate >= cast(getdate() as date) 
    and (OL.designStatus = 'des' or OL.designStatus = 'W/P')) as Z

where rowNumber = 1 and balance <> qtyOnHand 


select C.name, C.city, O.orderNumber, lineNumber, oldCode, customerQty, UMOrdered, tallyUM, WRD, SRO
    from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    inner join Items I on L.ob_Items_RID = I.ID
    where cast(O.dateEntered as date) = cast(getdate() as date)
    and (UMOrdered = 0 or tallyUM = 0) and L.WRD = 'W' and (L.ob_Items_RID < 10000 or L.ob_Items_RID > 10010)
 
    
select L.orderNumber, L.ID, I.oldCode, L.UMOrdered from orderLines L inner join Items I on L.ob_Items_RID = I.ID where ob_Orders_RID not in (select id from orders)    
    
select U.unit, length, qtyOnHand
    from Units U inner join UnitLengths L on L.ob_Units_RID = U.ID
    where qtyOnHand < 0
GO
