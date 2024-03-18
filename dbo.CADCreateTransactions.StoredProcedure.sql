USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CADCreateTransactions]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CADCreateTransactions]    

-- LAST CHANGE 09/21/16
-- ADDED LOGIC TO BREAK BUNDLES

@UnitID integer,
@orderLineID integer


as 


    
declare
@bundle     integer,
@noRecs     integer,
@unitNumber integer,
@CADDrill   integer

select @unitNumber = unit from Units where id = @unitID
select @CADDrill = CADDrills_RID from systemSettings


Select @Bundle = PcsBundle 
from OrderLines L inner join Items I on L.ob_Items_RID = I.ID
 where L.ID = @OrderLineID

if @Bundle  < 1 set @Bundle = 1;

with w as (select  U.ID as unitID, L.ID as unitLengthID, L.length, L.qtyOnHand, T.CADBalance, 
    case when L.qtyOnHand > T.CADBalance then T.CADBalance else L.qtyOnHand end as qtyToTake, modifier,

    -- IF CAD BALANCE < BUNDLE OR IF AFTER COMPUTING BUNDLE AMOUNT, REMAINING 
    --WOULD BE < LEFT THEN BREAK BUNDLE
    case when T.CADBalance < @bundle 
    OR (L.QtyOnHand > T.CADBalance 
        AND (L.QtyOnHand - round(T.CadBalance / @Bundle, 0) * @Bundle) < @Bundle)
            then T.CADBalance  
        when L.QtyOnHand > T.CADBalance then round(T.CadBalance / @Bundle, 0) * @Bundle
        when L.QtyOnHand <= T.CADBalance then round(L.QtyOnHand / @Bundle, 0) * @Bundle end 
            as qtyToTakeBundle, T.piecesAvailable

    From UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
    inner join OrderTally T on T.ob_OrderLines_RID = @OrderLineID and   L.length = T.length 
    where U.ID = @UnitID
        and T.ob_OrderLines_RID = @OrderLineID
        and L.qtyOnHand > 0 and T.CADBalance > 0)


Insert into CADTransactions (ID, BASVERSION, BASTIMESTAMP,
    ps_OrderLines_REN, ps_OrderLines_RID, ps_OrderLines_RMA,
    ps_UnitLengths_REN, ps_UnitLengths_RID, ps_UnitLengths_RMA,
    unitNumber, length,  lengthString, take, takeALl, 
    balance, designAccepted, workPapersProcessed, modifier, piecesAvailable, ps_CADDrills_REN, ps_CADDrills_RID,
    balanceBeforeTake)


select next value for BAS_IDGEN_SEQ as recno, 1, getDate(),
    'OrderLines', @OrderLineID, null,
    'UnitLengths', unitLengthID, null,
    @UnitNumber, length, '<b>' + rtrim(cast(length as char(2))) + '</b>''',
    case when qtyToTake < QtyToTakeBundle then qtyToTake else QtytoTakeBundle end, -- TAKE
    
    case when qtyToTake < QtyToTakeBundle and qtyToTake = qtyOnHand then 1 
         when qtyToTake >= QtyToTakeBundle and qtyToTakeBundle = qtyOnHand then 1 else 0 end, -- TAKEALL


    qtyOnHand,
-- - case when qtyToTake < QtyToTakeBundle then qtyToTake else QtytoTakeBundle end, -- BALANCE
    0,0, modifier, piecesAvailable, 'CADDrills', @CADDrill, qtyOnHand
    
    From w where qtyToTake > 0 and QtyToTakeBundle > 0
GO
