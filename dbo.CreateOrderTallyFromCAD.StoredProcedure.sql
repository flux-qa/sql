USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateOrderTallyFromCAD]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateOrderTallyFromCAD]
@orderLineID integer = 181091

as


declare 
    @itemID         integer,
    @LFperUM        float,
    @noTemplates    integer

-- FIND # OF TEMPLATE LINES AND INCREMENT MAX_ID 
select @itemID = ob_Items_RID, @LFperUM = LFperUM 
    from OrderLines L inner join Items I on L.ob_Items_RID = I.ID where L.ID = @orderLineID
    
select @noTemplates = count(*) from templates where ob_Items_RID = @itemID

delete from OrderTally where ob_OrderLines_RID = @orderLineID

insert into OrderTally (ID, BASVERSION, BASTIMESTAMP, length, lengthString, pieces, CADBalance,
    pct, costdeltaPct, ob_OrderLines_REN, ob_OrderLines_RID, ob_OrderLines_RMA,
    piecesStock, piecesAvailable, qtyUM, qtyLF, value, noUnits)
    
select NEXT VALUE FOR BAS_IDGEN_SEQ, 1, getdate(), 
    T.length, '<b>' + rtrim(cast(T.length as char(3))) + '</b>''' as lengthString,
    round(L.LFMaxQty * T.suggestedPct / T.length * 0.01,0) as pieces, 
    round(L.LFMaxQty * T.suggestedPct / T.length * 0.01,0) as CADBalance,
    suggestedPct as pct, isNull(T.aboveTallyPct,0) as costDeltaPct,
    'OrderLines', @orderLineID, 'om_OrderTally', totalPiecesForLength,
    totalPiecesForLength - isNull(piecesAllocated,0),
    round(totalLFForLength / LFperUM,0) as qtyUM, totalLFForLength,
    case when T.aboveTallyPct > 200 then '++' when T.aboveTallyPct > 100 then '+' 
    when T.aboveTallyPct > 0 then '-' else '' end, Z.noUnits

    from OrderLines L inner join Items I on L.ob_Items_RID = I.ID
    inner join Templates T on T.ob_Items_RID = I.ID  
    
    inner join (select length, sum(qtyOnHand) as totalPiecesForLength,
        sum(length * qtyOnHand) as totalLFForLength, count(*) as noUnits
        from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
        where U.ob_Items_RID = @itemID and qtyOnHand > 0 AND U.pocketwoodflag = 0 
        group by length) as Z on T.length = Z.length
        
    left outer join (select length, sum(pieces) as piecesAllocated 
        from ORDERTALLY T 
        inner join ORDERLINES L on T.ob_OrderLines_RID = L.ID
        where L.ob_Items_RID = @ItemID and L.UmShipped = 0 group by length) as Y
        on T.length = Y.length       
        
    where L.ID = @orderLineID
GO
