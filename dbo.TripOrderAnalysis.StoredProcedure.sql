USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[TripOrderAnalysis]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[TripOrderAnalysis]

as

print  'Order Lines with Trip number NOT on Trip'
declare @noRecs integer
select  @noRecs = count(*)
    from OrderLines L 
    where L.tripNumber > 0 and L.id not in  (select ps_OrderLines_RID from TripStopDetails)
    
if @noRecs > 0 
select  max('Order Lines with Trip Number NOT on Trip') as type, count(*)
    from OrderLines L 
    where L.tripNumber > 0 and L.id not in  (select ps_OrderLines_RID from TripStopDetails)
 
select @noRecs = count(*)
    from TripStopDetails TSD inner join OrderLines L on TSD.ps_OrderLines_RID = L.ID
    inner join TripStops TS on TSD.ob_TripStops_RID = TS.ID
    inner join TripCalendar TC on TS.ob_TripCalendar_RID = TC.ID
    where L.tripNumber = 0
if @noRecs > 0  
select 'Order Lines Tripped with no trip Number' as type, L.ID, L.orderNumber, L.lineNumber, I.oldCode as code, L.UMOrdered, TC.tripNumber, TC.startTime
    from TripStopDetails TSD inner join OrderLines L on TSD.ps_OrderLines_RID = L.ID
    inner join TripStops TS on TSD.ob_TripStops_RID = TS.ID
    inner join TripCalendar TC on TS.ob_TripCalendar_RID = TC.ID
    inner join Items I on L.ob_Items_RID = I.ID
    where L.tripNumber = 0
    
Print 'Customers with No Sector' 
select @noRecs = count(*)
    from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    where C.ps_Sector_RID = 0 and L.UMShipped = 0  
if @NoRecs > 0      
select distinct 'Customers with No Sector'   as type, C.name, c.city
    from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    where C.ps_Sector_RID = 0 and L.UMShipped = 0    

Print 'Items OverSold'
select 'Items OverSold' as type, C.name, O.orderNumber, I.oldCode as code, I.internalDescription as item,
    I.UMStock as stock, I.UMPocketWood as PW, L.UMOrdered as ordered, O.dateEntered, C.fieldRep as rep
    from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    inner join Items I on L.ob_Items_RID = I.ID
    where L.UMShipped = 0 and L.WRD = 'W' and L.ps_PurchaseLines_RID is null AND 
    L.ps_LinkToContractorOrderLine_RID is null AND L.UMOrdered > I.UMStock
    order by I.oldCode, O.dateEntered
    
print 'Order headers with No OrderLines'
select @noRecs = count(*)
    from Orders O inner join Customers C on O.ob_Customers_RID = C.ID
    where O.ID not in (select ob_orders_RID from orderLines)
if @noRecs > 0     
select 'Order headers with No OrderLines' as type, orderNumber, dateEntered, C.name
    from Orders O inner join Customers C on O.ob_Customers_RID = C.ID
    where O.ID not in (select ob_orders_RID from orderLines)
    
    
select I.oldCode as code, I.internalDescription as item, T.length, sum(T.pieces) as piecesOrdered, max(isNull(Z.piecesOnHand,0)) as piecesOnHand, 
sum(T.pieces) - max(isNull(Z.piecesOnHand,0)) as short, count(distinct L.ID) as noOrders

    from OrderTally T inner join OrderLines L on T.ob_OrderLines_RID = L.ID
    inner join Items I on L.ob_Items_RID = I.ID
    left outer join (select U.ob_Items_RID as itemID, L.length, sum(L.qtyOnHand) as piecesOnHand
        from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
        where L.qtyOnHand > 0 and U.pocketWoodFlag = 0 
        group by U.ob_Items_RID, L.length) as Z on Z.itemID = I.ID and Z.length = T.length
          
    where L.UMShipped = 0 and L.WRD = 'W' and L.ps_PurchaseLines_RID is null AND 
    L.ps_LinkToContractorOrderLine_RID is null  
    
    group by I.oldCode, I.internalDescription, T.length
    having sum(T.pieces) > max(isnull(Z.piecesOnHand,0))
    order by I.oldCode, T.length
    
    select oldCode as code, internalDescription as item, count(*) as noLens
    from (select  I.oldCode, I.internalDescription, T.length
    --count(distinct T.length) as noLens
        from OrderTally T inner join OrderLines L on T.ob_OrderLines_RID = L.ID
    inner join Items I on L.ob_Items_RID = I.ID
    left outer join (select U.ob_Items_RID as itemID, L.length, sum(L.qtyOnHand) as piecesOnHand
        from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
        where L.qtyOnHand > 0 and U.pocketWoodFlag = 0 
        group by U.ob_Items_RID, L.length) as Z on Z.itemID = I.ID and Z.length = T.length
          
    where L.UMShipped = 0 and L.WRD = 'W' and L.ps_PurchaseLines_RID is null
    --and i.oldcode = '143B'
    
    group by I.oldCode, I.internalDescription, T.length
    having sum(T.pieces) > max(isnull(Z.piecesOnHand,0))) as Y
    group by oldcode, internaldescription
    order by oldCode
GO
