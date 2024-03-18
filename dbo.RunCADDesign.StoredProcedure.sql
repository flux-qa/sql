USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[RunCADDesign]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[RunCADDesign]
  
/*
* this process is the main calling process to find a unit and create all of the transactions
*
* IF SKIP INTACT IS 0 THEN WILL TAKE THE BEST MATCHING UNIT, OTHERWISE, WILL SKIP INTACT UNITS
* -- changed the logic to LOOP in this process
*
* -- last change 05/09/18
*/


@orderLineID integer,
@SkipIntact integer = 0,
@designDate date,
@MaxNoSourceUnits integer,
@UMDesigned integer OUTPUT,
@piecesDesigned integer OUTPUT


AS

set nocount ON;

set @maxNoSourceUnits = 12


Declare @item           Integer, 		
        @Bundle         Integer,
        @UnitID         Integer,
        @maxID          Integer,
        @TotalCADPieces Integer,
        @inPlayFlag     Integer,
        @LFperUM         Float

exec CADPreProcess @OrderLineID -- DELETE SOME RECORDS, UPDATE ORDERLINETALLY

if @designDate is null set @designDate = getDate()

-- GET THE ITEM ID AND THE PIECES / BUNDLE
Select @Item = L.ob_Items_RID, 
    @Bundle = I.PcsBundle,
    @LFperUM = I.LFperUM
    from OrderLines L inner join Items I on L.ob_Items_RID = I.ID
    where L.ID = @OrderLineID

if @Bundle  < 1 set @Bundle = 1;

select @TotalCADPieces = sum(CADBalance) 
    from ORDERTALLY where ob_OrderLines_RID = @OrderLineID

WHILE @MaxNoSourceUnits > 0 AND @TotalCADPieces > 0 BEGIN
    
  exec CADFindBestUnit @orderLineId, @item, 1, @designDate,  @unitID OUT
  IF @unitID IS NULL
    exec CADFindBestUnit @orderLineId, @item, 0, @designDate,  @unitID OUT
        
    print 'the unit is ' + cast(@unitID as char(7)) + '  ' + convert(char(30), getDate(), 108)

    if @UnitID is NULL BREAK -- IF NO UNIT FOUND, THEN END THE LOOP

    -- SEE IF THIS UNIT IS "INPLAY"
    select @inPlayFlag = count(*) from CADSOURCEUNITS 
        where ps_Unit_RID = @UnitID 
        and dateDesigned >= @designDate and designAccepted = 1

    if @inPlayFlag > 1 set @inPlayFlag = 1

    begin transaction
        -- SAVE SELECTED PIECES FOR *BEST* SELECTED UNIT IN CAD TRANSACTIONS
        exec CADCreateTransactions @UnitID, @OrderLineID

        -- CREATE THE SOURCEUNIT
        exec CADCreateSourceUnit @UnitID, @OrderLineID, @inPlayFlag, @designDate

        -- CREATE THE SOURCELENGTHS -- MOVED TO WITHIN THE LOOP ON 5/25/18
        exec CADCreateSourceLengths @UnitID, @OrderLineID
        
        
        -- UPDATE THE ORDERTALLY TABLE
        update ORDERTALLY
            set CADBalance = CADBalance - take
            from ORDERTALLY T 
            inner join CADTRANSACTIONS C 
                on C.ps_OrderLines_RID = T.ob_OrderLines_RID and T.length = C.length
            inner join UNITLENGTHS L on C.ps_UnitLengths_RID = L.ID
            inner join UNITS U on U.ID = L.ob_Units_RID
            where T.ob_OrderLines_RID = @OrderLineID and U.ID = @UnitID

    commit transaction

    set @MaxNoSourceUnits = @MaxNoSourceUnits - 1
    select @TotalCADPieces = sum(CADBalance) 
        from ORDERTALLY where ob_OrderLines_RID = @OrderLineID
    
--    if @TotalCADPieces < 1 BREAK        -- IF NO PIECES LEFT TO DESIGN, THEN END THE  LOOP


END -- END WHILE

-- Update Balance String in Order Tally
update ORDERTALLY
    set CADBalanceString = case when CADBalance = 0 then '' 
    when CADBalance < 0 then '+' + RTRIM(Cast(ABS(CADBalance) as char(4)))
    else '(-' + RTRIM(Cast(ABS(CADBalance) as char(4))) + ')' end
    from ORDERTALLY T 
    where T.ob_OrderLines_RID = @OrderLineID


update CADTransactions set 
balance = balance - take
where ps_OrderLines_RID = @OrderLineID

update CADTransactions set 

balanceString = case when take >= balance then ' -- '
else cast(balance as char(4)) end,
took = take,
tookAll = takeAll
where ps_OrderLines_RID = @OrderLineID


select @UMDesigned = ROUND(sum(length * take / @LFperUM),0), @piecesDesigned = sum(take)
    from CADTRANSACTIONS 
    where ps_OrderLines_RID = @OrderLineID
GO
