USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateOrderTallyFromWholeUnits]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateOrderTallyFromWholeUnits]


@ID         Integer,
@Item       Integer,
@UMOrdered  Integer OUTPUT

as

Set NOCOUNT ON


declare
@totalLF    Integer,
@LFperUM     Float,
@noRecs     Integer

-- DELETE ANY PREVIOUS TALLY RECORDS
Delete From OrderTally where ob_OrderLines_RID = @ID

select @LFperUM = LFperUM from ITEMS where ID = @Item;

-- CTE HAS THE LENGTH, THE TOTAL PIECES FROM ASSIGNED UNITS AND TOTAL PIECES FROM ALL UNITS THIS ITEM, THIS LENGTH
with w as (select L.length, sum(L.qtyOnHand) as unitPieces, max(totalPieces) as totalPieces
    from UNITLENGTHS L inner join  ORDERUNITS U on L.ob_Units_RID = U.ps_Units_RID
        inner join (select length, sum(qtyOnHand) as totalPieces 
            from UNITLENGTHS L1 inner join UNITS U1 on L1.ob_Units_RID = U1.ID
            where U1.ob_Items_RID = @Item group by Length) as M on L.length = M.length
    where U.ob_OrderLines_RID = @ID
group by L.length)


-- CREATE THE ORDER TALLY

Insert into OrderTally 
    (ID, BASVERSION, BASTIMESTAMP, 
    ob_OrderLines_REN, ob_OrderLines_RID, ob_OrderLines_RMA, 
    Length, Pieces,  piecesStock)

    select NEXT VALUE FOR BAS_IDGEN_SEQ, 1, getDate(), 
    'OrderLines', @ID, 'om_OrderTally', length, unitPieces, totalPieces from w   



-- GET THE TOTALLF OF THE TALLY AND IF > 0 THEN COMPUTE THE PCT OF EACH LENGTH
select @totalLF = sum(length * pieces), @noRecs = count(*)
 from OrderTally where ob_OrderLines_RID = @ID

-- COMPUTE THE PCT OF EACH LENGTH, THE QTY LF AND UM
IF @totalLF > 0
    Update OrderTally 
        set pct = round(100.0 * length * pieces / @TotalLF,1), 
        qtyLF = length * pieces,
        qtyUM = round(length * pieces / @LFperUM,0)
    FROM OrderTally 
    where ob_OrderLines_RID = @ID

-- Return the TotalUM On Order
set @UMOrdered = ROUND(@totalLF / @LFperUM,0)
GO
