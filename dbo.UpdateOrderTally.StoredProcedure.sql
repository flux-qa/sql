USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateOrderTally]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateOrderTally]

-- last change 09/07/18 to fix NULLS!

@orderLineID        integer = 1317371,
@UMOrdered          integer = 1000

as
	
Declare 
@Item           integer,
@LFRequired     integer,
@LFperUM        float,
@Bundle         integer,

@LFToDesign     integer,
@LFComputed     integer,
@pctDesigned    decimal(5,1),
@loopCounter    integer = 20,
@direction      varchar(4) = '',
@deltaPct       decimal(4,1) = 10

select @item = I.ID, @bundle = I.pcsBundle, @LFperUM = I.LFperUM
from Items I inner join OrderLines L on L.ob_Items_RID = I.ID
 where L.ID = @orderLineID

if @Bundle < 1 or @Bundle is null set @Bundle = 1

set @LFToDesign = @UMOrdered * @LFPerUM


update OrderTally set pieces = null, modifier = '', qtyUM = null, qtyLF = null, pct = null,
    piecesStock =  
    case when isNull(Y.pcsAllocated,0) >= isNull(totalPiecesForLength,0) then 0 
    else isNull(totalPiecesForLength,0) - isnull(Y.pcsAllocated,0) end  
    from OrderTally OT inner join OrderLines L on OT.ob_OrderLines_RID = L.ID
    inner join (select U.ob_Items_RID, length, sum(qtyOnHand) as totalPiecesForLength
        from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
        where qtyOnHand > 0 AND U.pocketwoodflag = 0 group by U.ob_Items_RID, length) as Z
        on L.ob_Items_RID = Z.ob_Items_RID and OT.length = Z.length
        
    left outer join (select length, sum(pieces) as pcsAllocated 
    FROM ORDERTALLY T 
    inner join ORDERLINES L on T.ob_OrderLines_RID = L.ID
    WHERE L.ob_Items_RID = @Item and L.UmShipped = 0
    AND L.ID <> @OrderLineID 
     group by length) as Y
    on OT.length = Y.length
    
    where L.ID = @OrderLineID
   


if @LFRequired < 1 return


WHILE @loopCounter > 0 BEGIN
    select @LFComputed = sum(length * pcs) from (
        select Q.length, 
        case when piecesStock < floor(0.01   * Q.suggestedPct * 
        -- USE ORIGIANL QTY IF VALUABLE ITEM AND INCREASING THE QTY TO DESIGN
        case when @direction = 'Up' AND Q.costDeltaPctFromTemplate IS NOT NULL AND Q.costDeltaPctFromTemplate > 100 
            then @LFRequired else  @LFToDesign end
                  
         / Q.length) then piecesStock
            else floor(0.01 * Q.suggestedPct * @LFToDesign / Q.length / @bundle) * @bundle end as pcs         
        from OrderTally Q 
        where Q.ob_OrderLines_RID = @OrderLineID) as Z
    
    
    set @pctDesigned = 100.0 * @LFComputed / @LFRequired
    
    print 'Computed ' + cast(@pctDesigned as varchar(5)) + ' % = ' + cast(@LFComputed as varchar(5)) +  
     ' LF of ' + cast(@LFToDesign as varchar(5)) + ' delta Pct = ' + cast(@DeltaPct as varchar(4))
    
    -- IF AT LEAST 90% DESIGNED THEN WE ARE GOOD
    IF @pctDesigned > 90 AND @pctDesigned < 100 break
    
    -- IF < 90% THEN HAVE TO INCREASE STARTING AT 10% INCREMENTS
    IF @pctDesigned < 90 begin
        -- IF WE WERE GOING DOWN, THEN DIVIDE DELTA PCT IN HALF
        if @direction = 'Down' set @deltaPct = @deltaPct / 1.5
        set @direction = 'Up'
        
        set @LFToDesign = @LFToDesign + floor(@LFToDesign * @deltaPct * 0.01)
        END
    
        -- IF < 100% THEN HAVE TO DECREASE STARTING AT 10% INCREMENTS
    IF @pctDesigned > 100 begin
        -- IF WE WERE GOING UP, THEN DIVIDE DELTA PCT IN HALF
        if @direction = 'Up' set @deltaPct = @deltaPct / 1.5
        set @direction = 'Down'
      
        set @LFToDesign = @LFToDesign - floor(@LFToDesign * @deltaPct * 0.01)
        END
  
    if @deltaPct < 0.5 and @direction = 'Up' break
    
    set @loopCounter = @loopCounter - 1
    
    END
    
    
-- NOW WE HAVE A QTY TO COMPUTE THE TALLY WITH
    
update OrderTally
    set pieces = floor(case when piecesStock < floor(0.01   * Q.suggestedPct *     
        case when Q.costDeltaPctFromTemplate IS NOT NULL AND Q.costDeltaPctFromTemplate > 100 
            then @LFRequired else  @LFToDesign end 
        / Q.length) then piecesStock
            else floor(0.01   * Q.suggestedPct * @LFToDesign / Q.length / @bundle) * @bundle end),
        costDeltaPct = null
            
    from OrderTally Q 
    where Q.ob_OrderLines_RID = @OrderLineID

update OrderTally set pct = case when pieces is null or pieces = 0 or @LFComputed = 0 or @LFComputed is null then null
    else round(100.0 * length * pieces / @LFComputed,0) end, 
    qtyUM = ROUND(length * pieces / case when @LFperUM is NULL or @LFperUM = 0 then 1 else @LFperUM END,0),
    qtyLF = length * pieces
    where ob_OrderLines_RID = @OrderLineID
GO
