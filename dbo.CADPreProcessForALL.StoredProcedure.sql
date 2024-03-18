USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CADPreProcessForALL]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CADPreProcessForALL]

as


drop table OrderLinesForCad

select ID, ob_Items_RID as item into OrderLinesForCad
    from ORDERLINES where UMShipped = 0 and designStatus = ''

CREATE CLUSTERED INDEX idx_OrderLinesForCAD on OrderLinesForCAD(ID)

update ORDERTALLY 
set CADBalance = pieces, 
CADBalanceString = '',
noUnits = isNull(Z.noUnits,0), 
piecesStock = isNull(Z.totPcs,0), 
piecesAvailable = isNull(Z.totPcs,0) - isNull(Y.pcsAllocated,0),
lengthString = '<b>' + RTRIM(cast(T.length as char(2))) + '</b>''',
qtyLF = Z.qtyLF,
qtyUM = Z.qtyUM


from ORDERTALLY T 
    inner join OrderLinesForCAD L on T.ob_OrderLines_RID = L.ID
    inner join ITEMS I on L.item = I.ID

left outer join (select U.ob_Items_RID as item, UL.length, 
    sum(qtyOnHand) as totPcs,
    count(distinct U.ID) as noUnits,
    sum(UL.length * UL.qtyOnHand) as qtyLF,
    round(sum(UL.length * UL.qtyOnHand / I.LFperUM),0) as qtyUM
    from UNITLENGTHS UL    
    inner join UNITS U on UL.ob_Units_RID = U.ID
    inner join Items I on U.ob_Items_RID = I.ID
--    inner join OrderLinesForCAD OL on U.ob_Items_RID = OL.item

    where  U.ob_Items_RID in (select distinct item from orderLinesForCAD) AND
    UL.qtyOnHand > 0 AND U.unitType <> 'T' and U.pocketWoodFlag = 0
    group by U.ob_Items_RID, UL.length) as Z on I.ID = Z.item AND T.length = Z.length

left outer join (select I.ID as item, length, sum(pieces) as pcsAllocated 
    FROM ORDERTALLY T 
    inner join OrderLinesForCAD OL on T.ob_OrderLines_RID = OL.ID
    inner join ITEMS I on I.ID = OL.item 
    group by I.ID, length) as Y  on I.ID = Y.item AND T.length = Y.length
 
-- PULLED NEXT UPDATE OUT OF PREVIOUS ONE FOR PERFORMANCE
update OrderTally set value = T.value
    from OrderTally OT inner join OrderLinesForCAD OL on OT.ob_OrderLines_RID = OL.ID
    inner join Templates T on OL.item = T.ob_Items_RID and OT.length = T.length


delete from ORDERUNITS
from ORDERUNITS U inner join ORDERLINES L on U.ob_OrderLines_RID = L.ID
and L.UMShipped= 0 and L.designStatus = '' and U.wholeUnitAssigned = 0


Update ORDERLINES
set CADGeneratedDesignComments = case when designComments IS null then '' else LTRIM(RTRIM(designComments)) end
where UMShipped = 0 

-- NOW UPDATE THE CAD COMMENTS -- ADD WHOLE UNIT MSG
Update ORDERLINES
set CADGeneratedDesignComments = 'W/U ' + RTRIM(CADGeneratedDesignComments)
where UMShipped = 0 AND wholeUnits = 1

-- SHOW VPO # 
Update ORDERLINES
set CADGeneratedDesignComments = 'VPO: ' + RTRIM(LTRIM(CAST(P.PONumber as char(10)))) + ' ' +
RTRIM(CADGeneratedDesignComments)

FROM ORDERLINES L 
inner join PURCHASELINES PL on L.ps_PurchaseLines_RID = PL.ID
inner join PURCHASEORDERS P on PL.ob_PurchaseOrders_RID = P.ID
where L.UMShipped = 0 

-- SHOW IF TOO EARLY
Update ORDERLINES
set CADGeneratedDesignComments = '<span style="color: red;">*EARLY!:</span> ' + 
convert(char(3),DATENAME(weekday,O.deferred)) + ' ' + format(deferred, 'M/d/yy') + ' ' +
RTRIM(CADGeneratedDesignComments)

FROM ORDERLINES L 
inner join ORDERS O on O.ID = L.ob_Orders_RID 
where L.UMShipped = 0 and O.deferred > getDate()

Update OrderLines set designStatus = 'W/P', workpapersProcessed = 1 where ob_Items_RID between 10000 and 10010
and UMShipped = 0

Update OrderLines set CADGeneratedDesignComments = RTRIM(LTRIM(CADGeneratedDesignComments)) +  '<span style="color: red; font-weight:bold;">*COD*</span> '
From OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID 
where L.UMShipped = 0 AND O.codFlag = 1

Update OrderLines set CADGeneratedDesignComments = RTRIM(LTRIM(CADGeneratedDesignComments)) +  '<span style="color: red; font-weight:bold;">DESIGN HOLD!</span> '
From OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID 
where L.UMShipped = 0 AND O.holdDesign = 1
GO
