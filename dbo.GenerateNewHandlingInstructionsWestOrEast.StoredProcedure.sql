USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[GenerateNewHandlingInstructionsWestOrEast]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GenerateNewHandlingInstructionsWestOrEast]
    @designDate     date = '02/28/2023',
    @drillNumber    int = 1,
    @eastFlag       int = 0 -- set to 4 when using *WEST*
    
-- 05/05/2023 -- changed dup logic from adding to noOpen to sourceUsedInDup...

    
as

set nocount on

-- ANYTHING GREATER THAN @MaxSourcesInHande is HANDLED OUTDOORS
declare @maxSourcesInHandle integer = 2
declare @maxNoOpen          integer = 2
declare @skipCCheck         integer = 0


delete from TempNewHandle
  
        
 
-- 1st CREATE TABLE FOR EACH ORDER / SOURCE UNIT
-- ONLY FOR ITEMS WITH UNDIGS STARTING WITH 1-0
insert  into TempNewHandle (orderNo, orderLineID, itemID, sourceUnit, location, 
CLocation, unitType, maxLen, 
shortLength, takeAll, hardHandle, west4East0, noOpen, noIntact)
 
   select distinct OL.orderLineForDisplay as orderNo, OL.ID as orderLineID, 
   OL.ob_Items_RID as itemID,
    SU.unit as sourceUnit, SU.location, 
        case when @eastFlag = 0 
        AND left(SU.location,2) >= 'C1' 
        and left(SU.location,2) <= 'C4' then 
            cast(substring(SU.location,2,1) as integer) 
        when @eastFlag = 4 
        AND left(SU.location,2) >= 'C5' 
        and left(SU.location,2) <= 'C8' then 
            cast(substring(SU.location,2,1) as integer)     
            
            else 0 end as CLocation,  
    ISNULL(SU.unitType,'') as unitType, SU.longLength as maxLen, 
    SU.shortLength, 
    case when Z.ps_OrderLines_RID is null then 0 else 1 end as takeAll,
    case when SU.longLength = SU.shortlength then 0 else 1 end as hardHandle,
    case when (left(ISNULL(UML.location,SU.location),1) >= '1' and left(ISNULL(UML.location,SU.location),1) <= '5')  or 
    (left(ISNULL(UML.location,SU.location),2) >= 'C5' and left(ISNULL(UML.location,SU.location),2) <='C8')
	then 4
    when (left(ISNULL(UML.location,SU.location),1) >= '6' and left(ISNULL(UML.location,SU.location),1) <= '9') or 
    left(ISNULL(UML.location,SU.location),1) = '0' or 
    (left(ISNULL(UML.location, SU.location),2) >= 'C1' and left(ISNULL(UML.location, SU.location),2) <='C4') 
	then 0 else 1 end as west4East0, 0, 0
    
    from CADDrills D inner join CADTransactions T on T.ps_CADDrills_RID = D.ID
    inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
    inner join Units SU on L.ob_Units_RID = SU.ID
    inner join OrderLines OL on T.ps_OrderLines_RID = OL.ID
    left outer join UndigByMaxLen UML on UML.ob_Items_RID = SU.ob_Items_RID and UML.maxlen = SU.longLength 
    -- SEE IF ANY UNITS FOR THIS ORDERLINE HAVE LENGTHS THAT ARE USED UP
    left outer join (select distinct ps_OrderLines_RID 
        from CADDrills D inner join CADTransactions T on T.ps_CADDrills_RID = D.ID
        where D.designDate = @designDate and D.drillNumber = @drillNumber and T.takeAll = 1) 
            as Z on OL.ID = Z.ps_OrderLines_RID
    where D.designDate = @designDate and D.drillNumber = @drillNumber
    
 
-- 3/15/22 BELOW WILL SET THE ONES (1) TO EITHER 0 OR 4 IF ANY OTHER LENGTHS HAVE AN EAST OR WEST SIDE
update T1 set west4East0 = T2.west4East0
from TempNewHandle T1
inner join TempNewHandle T2 on T1.itemID = T2.itemID
where T1.west4East0 = 1 and t2.west4East0 <> 1 
 
-- DELETE LINES THAT ARE NOT EAST (OR WEST) 
delete from TempNewHandle where west4East0 <> @eastFlag     
 
-- UPDATE THE NUMBER OF NON-INTACT SOURCE UNITS
update TempNewHandle set noOpen = Z.noNonIntact
from TempNewHandle T inner join  
(select orderLineID, count(*) as noNonIntact 
from TempNewHandle T inner join Units U on T.sourceUnit = U.Unit
where (len(U.location) = 3 AND (left(U.location,1) = 'C' or left(U.location,2) = '1L' or left(U.location,2) = '0R')) OR 
    (len(U.location) = 4 and left(U.location,1) >= '0' and left(U.location,1) <= '9')
group by orderLineID) as Z on Z.orderLineID = T.orderLineID 
    
    
-- Next Update # of Intact and Open Source Units      
Update TempNewHandle set noIntact = Z.totSource - noOpen
from TempNewHandle as Y inner join (select orderLineID, count(*) as totSource
    from TempNewHandle group by orderLineID) as Z on Y.orderLineID = Z.orderLineID 

       
-- Next get the Lowest ID to figure out which was designed 1st
update TempNewHandle set firstID = Z.firstID
    from TempNewHandle as Y inner join (select ps_OrderLines_RID, min(ID) as firstID 
    from CADTransactions group by ps_OrderLines_RID) as Z
        on Y.orderLineID = Z.ps_OrderLines_RID

-- Next get total Source Units for all like items
update TempNewHandle set totalSourceUnits = Z.noUnits, totalHandles = Z.noHandles
from TempNewHandle as A inner join 
    (select A.itemID, count(*) as noUnits, count(distinct A.orderLineID) as noHandles
    --A.orderLineID, B.orderLineID, A.itemID, A.sourceUnit
    from TempNewHandle as A inner join TempNewHandle as B 
        on A.sourceUnit = B.sourceUnit and A.orderLineID <> B.orderLineID
    group by A.itemID) as Z on A.itemID = Z.itemID

/*
-- THIS WAS OLD LOGIC FOR UNITS USED IN MULTIPLE ORDERS -- COMMENTED OUT 02/27/23 

-- FLAG ALL ORDERS THAT HAVE AT LEAST ONE DUP SOURCE UNIT
update TempNewHandle set sourceUsedInDupTargets = 1
from TempNewHandle T where orderNo in (
    select orderNo from TempNewHandle where sourceUnit in (
        select sourceunit from TempNewHandle
        group by sourceunit having count(*) > 1))

-- IF DUPS THEN USE THE MAX LENGTH, MAX OPEN AND MAX INTACT UNITS
update TempNewHandle set noOpen = Y.maxOpen, noIntact = Y.maxIntact, maxLen = Y.maxLen
from TempNewHandle T inner join (select orderLineID, max(noOpen) as maxOpen, 
    max(noIntact) as maxIntact, max(maxLen) as maxLen
    from (select orderLineID, sourceUnit, noOpen, noIntact, maxLen 
        from TempNewHandle T where sourceUnit in (
            select sourceunit from TempNewHandle
            where noIntact + noOpen <= @maxSourcesInHandle
            group by sourceunit having count(*) > 1)) as Z
    group by orderLineID) as Y on T.orderLineID = Y.orderLineID
	
*/	

-- NEW COMBINE LOGIC 02/27/23	
	
/*	
-- STEP 1 (THE TOUGH ONE), FIND ANY NON-INTACT UNIT THAT IS USED IN MORE THAN 1 ORDER, AND COUNT THE # OF
-- DIFFERENT ORDERS IT IS USED IN.  SUBTRACT 1 FROM THAT (SINCE STEP 1 TOOK CARE OF UNITS IN 
-- THE SAME ORDER NUMBER, AND ADD THAT TO THE TOTAL # OF UNITS
update tempNewHandle set noOpen = noOpen + amtToAdd, sourceUsedInDupTargets = 1
	from tempNewHandle T inner join
		(select sourceUnit, count(*) -1 as amtToAdd from tempNewHandle where sourceUnit in
			(select sourceUnit from tempNewHandle where noOpen > 0 group by sourceUnit having count(*) > 1)
			group by sourceUnit) as T2 on T.sourceUnit = T2.sourceUnit

-- DO THE SAME FOR INTACT UNITS
update tempNewHandle set noIntact = noIntact + amtToAdd, sourceUsedInDupTargets = 1
	from tempNewHandle T inner join
		(select sourceUnit, count(*) -1 as amtToAdd from tempNewHandle where sourceUnit in
			(select sourceUnit from tempNewHandle where noIntact > 0 group by sourceUnit having count(*) > 1)
			group by sourceUnit) as T2 on T.sourceUnit = T2.sourceUnit

-- STEP 3 FIND THE MAX OPEN, INTACT AND MAXLEN FOR ANY ORDERS SHARING SAME UNIT 
update tempNewHandle set noOpen = maxNoOpen, noIntact = maxNoIntact, maxLen = T2.maxMaxLen
	from tempNewHandle T inner join
		(select sourceUnit, max(noOpen) as maxnoOpen, max(noIntact) as maxNoIntact, max(maxLen) as maxMaxLen 
		from tempNewHandle where sourceUnit in
			(select sourceUnit from tempNewHandle group by sourceUnit having count(*) > 1)
			group by sourceUnit) as T2 on T.sourceUnit = T2.sourceUnit


-- STEP 4 GET THE MAX # OF UNITS FOR EACH SAME orderNo
update tempNewHandle set noOpen = maxnoOpen, noIntact = maxNoIntact, maxLen = maxMaxLen
from tempNewHandle T inner join (select orderNo, max(noOpen) as maxnoOpen, max(noIntact) as maxNoIntact, max(maxLen) as maxMaxLen 
	 from tempNewHandle group by orderNo) as T2 on T.orderNo = T2.orderNo	
	
*/
	
-- END NEW LOGIC 02/27/23	

-- NEWEST COMBINE LOGIC 
 declare @sourceUnit integer 

-- FIND ALL SOURCE UNITS USED IN 2 OR MORE TARGETS
declare myCursor cursor for
	select sourceUnit from TempNewHandle
		group by SourceUnit	
		having count(*) > 1

open myCursor
fetch next from myCursor into @sourceUnit
WHILE @@FETCH_STATUS = 0  
BEGIN 
	-- FIND ALL THE ORDERS FOR THIS SOURCE UNIT, ADD UP THE NUMBER OF DISTINCT UNITS 
	-- AND UPDATE THOSE ORDERS
	update tempNewHandle set sourceUsedInDupTargets = noSources -- CHANGED 05/05/23
	from TempNewhandle 
	inner join 	(select count(distinct sourceUnit) as noSources from TempNewHandle where orderNo in 
		(select orderNo from tempNewHandle where sourceUnit = @sourceUnit)) as Z on 1 = 1
	where orderNo in (select orderNo from tempNewHandle where sourceUnit = @sourceUnit)

	fetch next from myCursor into @sourceUnit
END
close myCursor
deallocate myCursor
 
 
 
 
 
 
 
-- IF MULTIPLE UNITS FOR SAME ORDER THEN USE THE MAX LENGTH OF THE UNITS -- 01/24/23
		update TempNewHandle set maxLen = RealMaxLen 
		from TempNewHandle T inner join 
		(select orderNo, max(maxLen) as RealMaxLen from TempNewHandle group by orderno) as T2
		on T.orderNo = T2.orderNo 
 
 
		
-- ADD ANY WHOLE UNITS ASSIGNED TO NOINTACT. -- REMOVED 02/13/23
/*
update TempNewHandle
set noIntact = noIntact + ISNULL(noWholeUnits,0)
from TempNewHandle T inner join 
(select ps_OrderLines_RID, count(distinct ID) as noWholeUnits from Units
 WHERE unitType <> 'T'
group by ps_OrderLines_RID) as Z on T.orderLineID = Z.ps_OrderLines_RID
*/
-- IF ANY OrderLines have a CLocation > 0 then set ALL units on that orderLines to same cLocation
Update TempNewHandle
    set cLocation = Z.clocation
    from TempNewHandle T inner join 
    (select orderLineID, clocation from TempNewHandle where cLocation > 0) as Z
        on T.orderLineID = Z.orderLineID

-- select * from TempNewHandle  

declare @OKtoLoop           integer = 1
declare @orderLineID        integer
declare @orderLineID2       integer
declare @orderNo            varchar(10)
declare @maxLen             integer
declare @noSources          integer
declare @firstLocation      integer 
declare @lastLocation       integer
declare @sortOrder          integer = 10
declare @hardHandleFlag     integer = 0
declare @handleLocation     integer
declare @eastWestBay        integer = 0
declare @lastItemIDEorW		integer
declare @tempID				integer


set @firstLocation = 1 + @eastFlag      -- EAST = 1, WEST = 5
set @lastLocation = @firstLocation + 3  -- EAST = 4, WEST = 8
set @handleLocation = @firstLocation

if @eastFlag = 4 set @eastWestBay = 9

declare @loopCounter integer = 0


WHILE @OKtoLoop > 0 and @loopCounter < 1000 BEGIN
    SET @orderLineID = NULL
    set @orderLineID2 = NULL    -- USED TO ADD > 3 SOURCES AFTER 4 AND 8
    set @loopCounter = @loopCounter + 1

    
    --  2 or Less NON-INTACT NOT ALL USED UP SORT IN DECENDING ORDER OF # OF NON-INTACT
   
    -- IF 20 FT BAY LOOK FOR ANY LARGE > 16 FT MAX LEN
    IF @orderLineID IS NULL AND (@handleLocation = 1 or @handleLocation = 2 or 
        @handleLocation = 7 or @handleLocation = 8) BEGIN
        SELECT top 1 @orderlineID = orderLineID, @maxLen = maxLen, 
        @noSources = noOpen + noIntact 
        from TempNewHandle
        WHERE noOpen <= @maxNoOpen AND noIntact = 0 and takeAll = 0
        and (cLocation = 0 or cLocation = @handleLocation)
        ORDER by cLocation desc, maxLen DESC, noOpen DESC, firstID
    
        IF @OrderLineID IS NOT NULL begin 
            EXEC GenerateNewHandlingInstructionsCreateOutput @designDate, @drillNumber, 
            @orderLineID, @handleLocation, @sortOrder, 
            '2 or Less Non-Intact Not Dead', @eastFlag

        END
     END

    -- IF 16FT BAY LOOK FOR 13 - 16 FT MAX LEN
    IF @OrderLineID IS NULL AND (@handleLocation = 3 OR @handleLocation = 6) BEGIN 
        SELECT top 1 @orderlineID = orderLineID, @maxLen = maxLen, 
        @noSources = noOpen + noIntact 
        from TempNewHandle
        WHERE noOpen <= @maxNoOpen AND noIntact = 0 and takeAll = 0
        AND (maxLen <= 16 OR cLocation = @handleLocation)
        ORDER by cLocation desc, maxLen desc, noOpen Desc, firstID
    
        IF @OrderLineID IS NOT NULL BEGIN   
            EXEC GenerateNewHandlingInstructionsCreateOutput @designDate, @drillNumber, 
            @orderLineID, @handleLocation, @sortOrder, 
            '2 or Less Non-Intact Not Dead', @eastFlag
        END  
    END  
    
        -- IF 12FT BAY THEN ANY SIZE <= 12
        IF @OrderLineID IS NULL AND (@handleLocation = 4 OR @handleLocation = 5) BEGIN 
        SELECT top 1 @orderlineID = orderLineID, @maxLen = maxLen, 
        @noSources = noOpen + noIntact 
        from TempNewHandle
        WHERE noOpen <= @maxNoOpen AND noIntact = 0 and takeAll = 0
        AND (maxLen <= 12 or cLocation = @handleLocation)
        ORDER by cLocation desc, maxLen desc, noOpen desc, firstID
    
        IF @OrderLineID IS NOT NULL BEGIN   
            EXEC GenerateNewHandlingInstructionsCreateOutput @designDate, @drillNumber, 
            @orderLineID, @handleLocation, @sortOrder, 
            '2 or Less Non-Intact Not Dead', @eastFlag
        END
    END 
 
        
-- -----------------------------------------------------------------------------------------------------


    -- 2 or Less NON-INTACT  SORT IN DECENDING ORDER OF # OF NON-INTACT
   
    -- IF 20 FT BAY SORT BY MAX LENGTH DESCENDING
    IF @orderLineID IS NULL AND (@handleLocation = 1 or @handleLocation = 2 or 
        @handleLocation = 7 or @handleLocation = 8) BEGIN
        SELECT top 1 @orderlineID = orderLineID, @maxLen = maxLen, 
        @noSources = noOpen + noIntact 
        from TempNewHandle
        WHERE noOpen <= @maxNoOpen AND noIntact = 0 
        and (cLocation = 0 or cLocation = @handleLocation)
        ORDER by cLocation desc, maxLen DESC, noOpen DESC, firstID
    
        IF @OrderLineID IS NOT NULL BEGIN 
        EXEC GenerateNewHandlingInstructionsCreateOutput @designDate, @drillNumber, 
        @orderLineID, @handleLocation, @sortOrder, 
        '2 or Less Non-Intact', @eastFlag
        END
     END

    -- IF 16FT BAY LOOK FOR 13 - 16 FT MAX LEN
    IF @OrderLineID IS NULL AND (@handleLocation = 3 OR @handleLocation = 6) BEGIN 
        SELECT top 1 @orderlineID = orderLineID, @maxLen = maxLen, 
        @noSources = noOpen + noIntact 
        from TempNewHandle
        WHERE noOpen <= @maxNoOpen AND noIntact = 0
        AND (maxLen <= 16 or cLocation = @handleLocation)
        ORDER by cLocation desc, maxLen DESC, noOpen DESC, firstID

    
        IF @OrderLineID IS NOT NULL BEGIN   
            EXEC GenerateNewHandlingInstructionsCreateOutput @designDate, @drillNumber, 
            @orderLineID, @handleLocation, @sortOrder, 
            '2 or Less Non-Intact', @eastFlag
        END
    END  
    
        -- IF 12FT BAY THEN ANY SIZE <= 12
        IF @OrderLineID IS NULL AND (@handleLocation = 4 OR @handleLocation = 5) BEGIN 
        -- <= 12
        SELECT top 1 @orderlineID = orderLineID, @maxLen = maxLen, 
        @noSources = noOpen + noIntact 
        from TempNewHandle
        WHERE noOpen <= @maxNoOpen AND noIntact = 0 
        AND (maxLen <= 12 or cLocation = @handleLocation)
        ORDER by cLocation desc, maxLen DESC, noOpen DESC, firstID

    
        IF @OrderLineID IS NOT NULL BEGIN   
            EXEC GenerateNewHandlingInstructionsCreateOutput @designDate, @drillNumber, 
            @orderLineID, @handleLocation, @sortOrder, 
            '2 or Less Non-Intact', @eastFlag
        END
    END 
 
        
-- -----------------------------------------------------------------------------------------------------


    -- 2 or Less SORT IN DECENDING ORDER OF # OF NON-INTACT
   
    -- IF 20 FT BAY SORT BY MAX LENGTH DESCENDING
    IF @orderLineID IS NULL AND (@handleLocation = 1 or @handleLocation = 2 or 
        @handleLocation = 7 or @handleLocation = 8) BEGIN
        SELECT top 1 @orderlineID = orderLineID, @maxLen = maxLen, 
        @noSources = noOpen + noIntact 
        from TempNewHandle
        WHERE noOpen + noIntact <= @maxNoOpen
        and (cLocation = 0 or cLocation = @handleLocation)
        ORDER by cLocation desc, maxLen DESC, noIntact, noOpen DESC, firstID
   
        IF @OrderLineID IS NOT NULL BEGIN
        EXEC GenerateNewHandlingInstructionsCreateOutput @designDate, @drillNumber, 
        @orderLineID, @handleLocation, @sortOrder, 
        '2 or Less Units', @eastFlag
        END
     END

    -- IF 16FT BAY LOOK FOR 13 - 16 FT MAX LEN
    IF @OrderLineID IS NULL AND (@handleLocation = 3 OR @handleLocation = 6) BEGIN 
        SELECT top 1 @orderlineID = orderLineID, @maxLen = maxLen, 
        @noSources = noOpen + noIntact 
        from TempNewHandle
        WHERE noOpen + noIntact <= @maxNoOpen
        AND (maxLen <= 16 or cLocation = @handleLocation)
        ORDER by cLocation desc, maxLen DESC, noIntact, noOpen DESC, firstID

    
        IF @OrderLineID IS NOT NULL BEGIN  
            EXEC GenerateNewHandlingInstructionsCreateOutput @designDate, @drillNumber, 
            @orderLineID, @handleLocation, @sortOrder, 
            '2 or Less Units', @eastFlag
        END
    END  
    
        -- IF 12FT BAY THEN ANY SIZE <= 12
        IF @OrderLineID IS NULL AND (@handleLocation = 4 OR @handleLocation = 5) BEGIN 
        -- <= 12
        SELECT top 1 @orderlineID = orderLineID, @maxLen = maxLen, 
        @noSources = noOpen + noIntact 
        from TempNewHandle
        WHERE noOpen + noIntact <= @maxNoOpen
        AND (maxLen <= 12 or cLocation = @handleLocation)
        ORDER by cLocation desc, maxLen DESC, noIntact, noOpen DESC, firstID
    
        IF @OrderLineID IS NOT NULL BEGIN  
            EXEC GenerateNewHandlingInstructionsCreateOutput @designDate, @drillNumber, 
            @orderLineID, @handleLocation, @sortOrder, 
            '2 or Less Units', @eastFlag
        END
    END 
 
      
-- -----------------------------------------------------------------------------------------------------
/*
 * -- SEE IF ANY NON-INTACT, NOT ALL USED UP, > 2 SOURCES AFTER LOCATION 4 (OR 8)
*/


    IF @handleLocation = 4 OR @handleLocation = 8 BEGIN
        SELECT top 1 @orderlineID2 = orderLineID, @maxLen = maxLen, @noSources = noOpen + noIntact,
			@tempID = itemID
        from TempNewHandle
        WHERE noOpen + noIntact > @maxNoOpen 
        ORDER by cLocation desc, case when @lastItemIDEorW = itemID then 0 else 1 end, 
			noIntact, noOpen DESC, firstID
		-- ADDED LOGIC IN SORT TO PRIORTIZE IF SAME ITEM CODE	
    
        IF @OrderLineID2 IS NOT NULL BEGIN
           set @sortOrder = @sortOrder + 10
           EXEC GenerateNewHandlingInstructionsCreateOutput @designDate, @drillNumber, @orderLineID2, 
           @eastWestBay, @sortOrder, 'Over 2 Sources.', @eastFlag
			set @lastItemIDEorW = @tempID
           END 
    END 

-- -----------------------------------------------------------------------------------------------------
              

/*
 * -- SEE IF ANY NON-INTACT, NOT ALL USED UP TOTAL # OF SOURCES > 3 
*/
   
/*   
    IF @OrderLineID IS NULL  AND @orderLineID2 IS NULL BEGIN 
    SELECT top 1 @orderlineID = orderLineID, @maxLen = maxLen, @noSources = noOpen + noIntact 
    from TempNewHandle
    WHERE noOpen + noIntact > 3 
    ORDER by firstID

    IF @OrderLineID IS NOT NULL BEGIN
       EXEC GenerateNewHandlingInstructionsCreateOutput @designDate, @drillNumber, @orderLineID, 
       @eastWestBay, @sortOrder, 'Over 3 Sources', @eastFlag         
       END
    END 
*/
-- -----------------------------------------------------------------------------------------------------
               
    SET @handleLocation = @handleLocation + 1
    IF @handleLocation > @lastLocation SET @handleLocation = @firstLocation
    set @sortOrder = @sortOrder + 10
    
    select @OKtoLoop = count(*) from TempNewHandle   
    -- IF THIS LINE REACHED WITH @ORDERLINEID NULL THEN THERE WERE NO MATCHES
    --IF @orderLineID IS NULL AND @orderLineID2 IS NULL SET @OKtoLoop = 0
        
END
GO
