USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateShippableUnshippable]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateShippableUnshippable]

-- last change 5/24/18

as

delete from ShippableUnShippable
;

with w as (select O.originalShipTo_RID as custno,
    count(*) as noLines, cast(min(O.estDeliveryDate) as date) as estDelivery,
    round(sum(case when L.BMEsperLB > L.BMEsperFT3 then L.BMEsperLB else L.BMEsperFT3 end),1) as BMEs,
    sum(round(customerQty * actualPrice / per,0)) as saleAmount,
    sum(round(customerQty * (actualPrice - (projectedCost - freightCost)) / per,0)) as profit,
    sum(case when UMOrdered <= UMStock OR (I.ID >= 10000 and I.ID < 10010) then 0 else 1 end) as noStockFlag,
    sum(case when O.holdShipments = 1 or O.holdDesign = 1
    then 1 else 0 end) as creditHold

from Orders O inner join OrderLines L on L.ob_Orders_RID = O.ID
inner join Items I on L.ob_Items_RID = I.ID
inner join Customers C on O.originalShipTo_RID = C.ID
WHERE L.dateshipped is null AND L.UMShipped = 0 and L.WRD <> 'D' 
--and (I.ID < 10000 or I.ID > 10010)
group by O.originalShipTo_RID
)


insert into ShippableUnShippable (id, basversion, bastimestamp, name, add1, city, state, zip,
    fieldRep, outsidefieldrep, reps, sector, maxstops, truckcost, nolines, estdelivery, bmes, profit,
    creditHold, noStockFlag, freight, totalSale)

select C.ID, 1, getdate(), C.name, C.add1, C.city, C.state, C.zip, 
    left(C.fieldRep,2) as fieldrep, left(C.outsideFieldRep,2) as outsideFieldRep, 
    case when c.outsideFieldRep is null or C.outsidefieldRep = '' then left(c.fieldRep,2)
    else rtrim(left(c.fieldRep,2)) + '/' + left(c.outsideFieldRep,2) end as reps,
    S.name as sector, s.maxStops, s.truckCost, noLines, estDelivery, W.BMEs, 
    W.profit,
    case when w.creditHold > 0 
    --OR
    --(C.creditLimit > 0 and c.balance + w.saleAmount > c.creditLimit)
    
    then 1 else 0 end, case when w.noStockFlag > 0 then 1 else 0 end,
    case when s.maxStops > 1 and s.truckCost / (s.maxStops - 1) > W.BMEs * s.truckCost / 100.0
        THEN round(s.truckCost / (s.maxStops - 1),0) else round(W.BMEs * s.truckCost / 100.0,0) end,
    saleAmount

from W inner join Customers C on w.custno = C.ID
inner join Sectors S on C.ps_sector_RID = S.ID

--update ShippableUnShippable set profit = profit - freight
GO
