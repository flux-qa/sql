USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CADPreProcess]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CADPreProcess]       

@orderLineID integer

-- LAST CHANGE 05/29/2018
-- 10/01/2020 Fixed Allocated Count to USE designed Units

as


declare @itemID integer

select @itemID = ob_Items_RID from ORDERLINES where ID = @orderLineID

update ORDERTALLY 
set CADBalance = pieces, 
CADBalanceString = '',
noUnits = isNull(Z.noUnits,0), 
piecesStock = isNull(Z.totPcs,0), 
piecesAvailable = isNull(Z.totPcs,0) - isNull(Y.pcsAllocated,0),
lengthString = '<b>' + RTRIM(cast(T.length as char(2))) + '</b>''',
value = case when IT.aboveTallyPct > 200 then '++' when IT.aboveTallyPct > 100 then '+' 
    when IT.aboveTallyPct > 0 then '-' else '' end

from ORDERTALLY T 
    inner join ORDERLINES L on T.ob_OrderLines_RID = L.ID
    inner join ITEMS I on L.ob_Items_RID = I.ID
    left outer join TEMPLATES IT ON IT.ob_Items_RID = I.ID and IT.length = T.length

left outer join (select U.ob_Items_RID as item, UL.length, sum(qtyOnHand) as totPcs,
    sum(case when U.pocketWoodFlag = 1 then qtyOnHand else 0 end) as totPocketWood, 
    sum(case when U.pocketWoodFlag = 1 then 0 else 1 end) as noUnits
    from UNITLENGTHS UL inner join UNITS U on UL.ob_Units_RID = U.ID
    where U.ob_Items_RID = @ItemID and UL.qtyOnHand > 0 
    and U.pocketWoodFlag = 0 
    --and U.ps_OrderLines_RID is null
    group by U.ob_Items_RID, UL.length) as Z on I.ID = Z.item AND T.length = Z.length

left outer join (select length, sum(pieces) as pcsAllocated 
    FROM ORDERTALLY T 
    inner join ORDERLINES L on T.ob_OrderLines_RID = L.ID
    inner join ITEMS I on L.ob_Items_RID = I.ID 
    WHERE L.ob_Items_RID = @ItemID and L.UmShipped = 0  and 
        L.ps_PurchaseLines_RID is null group by length) as Y
    on T.length = Y.length

    where T.ob_OrderLines_RID = @OrderLineID


delete from CADSOURCEUNITS WHERE ps_OrderLines_RID = @OrderLineID
delete from CADSOURCELENGTHS WHERE ps_OrderLines_RID = @OrderLineID
delete from CADTRANSACTIONS WHERE ps_OrderLines_RID = @OrderLineID
delete from ORDERUNITS WHERE ob_OrderLines_RID = @OrderLineID AND wholeUnitAssigned = 0


    -- IF ANY UNITS ALREADY ASSIGNED, ADD THOSE PIECES TO SELECTED AND REDUCE CAD BALANCE
    update  OrderTally 
    set CADBalance = CADBalance - totPCS
        from OrderTally T inner join (select length, sum(QtyOnHand) as totPCS
        
        from UnitLengths L 
        --inner join Units U on L.ob_Units_RID = U.ID
        inner join OrderUnits O on O.ps_Units_RID = L.ob_Units_RID
        where O.ob_OrderLines_RID = @OrderLineID
         group by length) as Z
        on T.Length = Z.length
        where T.ob_OrderLines_RID = @OrderLineID


INSERT INTO CADSOURCEUNITS (
[ID], [BASVERSION], [BASTIMESTAMP], 
 [ps_Unit_REN], [ps_Unit_RID], [ps_Unit_RMA], 
[ps_OrderLines_REN], [ps_OrderLines_RID], [ps_OrderLines_RMA], 
pieces, taken, balance,  noLengths, designAccepted, workPapersProcessed,
dateDesigned, inPlay, wholeUnit) 

    select NEXT VALUE FOR BAS_IDGEN_SEQ, 1, getDate(),
    'Units', U.ID, null,
    'OrderLines', @orderLineID, null, 
    U.piecesStock, U.piecesStock, 0, z.noLengths, 0, 0,
    getDate(), 0, 1

    from  Units U
        inner join OrderUnits O on O.ps_Units_RID = U.ID
        inner join (select ob_Units_RID as ID, count(*) as noLengths from 
            UNITLENGTHS group by ob_Units_RID) as Z on U.ID = Z.ID
        where O.ob_OrderLines_RID = @OrderLineID
GO
