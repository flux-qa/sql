USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[JoshAutoPopulate]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[JoshAutoPopulate]

as

SET NOCOUNT ON

-- CONSTANTS
Declare
    @bayHeight          integer = 16 * 12,
    @bayDepth           integer = 4,
    @deepBays           varchar(200) = 'A-B, E-F, G-H, I-J, K-L',
    @eastLowNumberBays  varchar(5) = 'EGIK',
    @eastHighNumberBays varchar(5) = 'FHJL'
    
-- CURSOR VARIABLES
Declare @ID             integer,
        @oldCode        varchar(6),
        @maxLen         integer,
        @noUnits        integer,
        @inchesHigh     integer,
        @dateReceived   date,
        --@preferredAisle varchar(6),
        @bayNames       varchar(4),
        @runningTotalUM integer,
        @toDeep         integer,
        @rowno          integer,
        @lastReceived   date,
        @east1WestMinus1    integer,
        @eastWestMsg    varchar(10),
        @TDSUnit        integer
        
-- TEMP VARIABLES
Declare @bay            varchar(6),
        @available      integer,
        @newBay         integer = 0,
        @sameBay        integer = 0,
        @deltaLen       integer = 0,
        @noBay          integer = 0,
        @noMonthsDeep   integer = 4,
        @unit           integer
    
    
-- CLEAR THE BAY TOTALS
Update BayTotals set noUnits = 0, totUM = 0, totInches = 0, noItems = 0, availableInches = inchesHigh
Update BayTotals set availFeetInches = dbo.inchesToFeet(availableInches)



-- PRE POPULATE THEM WITH THE EXCLUSION LIST
update bayTotals set noUnits = Z.noUnits, totInches = Z.totInches,
    availableInches = AvailableInches - Z.totInches
from BayTotals B inner join 
    (select A.bay, sum(M.inchesHigh) as totinches, count(*) as noUnits
    from AutoBayExclusionList A 
    inner join Units U on A.bay = U.location
    inner join UnitMaxLenData M on M.ob_Item_RID = U.ob_Items_RID and M.maxLength = U.longLength
    where U.UMStock > 0
    group by A.bay) as Z on Z.bay = B.bay

delete from AutoBayTransactions


exec PopulateDeepBays
;
/*
with w as (select UML.ob_Item_RID, UML.maxLength,
    stockForLength, @noMonthsDeep * UML.monthlyUsage as Usage3M,
    case when @noMonthsDeep * UML.monthlyUsage >= StockForLength then 0 else 
        StockForLength - (@noMonthsDeep * UML.monthlyUsage) end as ToDeep
    from UnitMaxLenData UML 
    inner join (select ob_Items_RID, longlength, sum(UMStock) as StockForLength 
    from Units where UMStock > 0 and unitType = 'I'
    group by ob_Items_RID, longlength) as Z on Z.ob_Items_RID = UML.ob_Item_RID and Z.longLength = UML.maxLength)
*/
        
DECLARE myCursor CURSOR FAST_FORWARD  FOR   


select row_number()  over (partition by I.ID, U.longLength
        order by I.ID, U.longLength, U.dateReceived) as rowno,
    I.ID, I.oldCode, count(*) as noUnits,  U.longLength, M.inchesHigh, U.dateReceived, bayName,
    sum(U.UMStock)  as runningTotalUM,    
        max(W.toDeep) as toDeep, max(W.lastReceived) as lastReceived,
    max(case when UD.location IS NULL THEN 0 
    when left(UD.location,1) >= '1' and left(UD.location,1) <= '5' then -1 
    when left(UD.location,1) = '0' OR (left(UD.location,1) >= '6' and left(UD.location,1) <= '9') then 1 else 0 end) as East1WestMinus1,
    max(case when UD.location IS NULL THEN '' 
    when left(UD.location,1) >= '1' and left(UD.location,1) <= '5' then ' Want WEST' 
    when left(UD.location,1) = '0' OR (left(UD.location,1) >= '6' and left(UD.location,1) <= '9') then 'Want EAST' else '' end) as EastWestMsg,
    max(ISNULL(TDS.unit,0)) as TDSUnit
    from Units U inner join Items I on U.ob_Items_RID = I.ID    
    inner join  UnitMaxLenData M  on M.ob_Item_RID = U.ob_Items_RID and M.maxLength = U.longLength
    left outer join ToDeepStorage TDS on U.unit = TDS.unit
    -- USED TO GET EAST OR WEST
    left outer join UnDigByMaxLen UD on UD.ob_Items_RID = I.ID and UD.maxlen = U.longLength
    inner join (select UML.ob_Item_RID, UML.maxLength,
    stockForLength, case when bayName = 'A-B' then 2 else 1 end * @noMonthsDeep * UML.monthlyUsage as Usage3M,
    case when case when bayName = 'A-B' then 2 else 1 end * @noMonthsDeep * UML.monthlyUsage >= StockForLength OR UML.stdReceivedUnitSize * 2 >= StockForLength then 0  
        else StockForLength - (case when bayName = 'A-B' then 2 else 1 end * @noMonthsDeep * UML.monthlyUsage) end as ToDeep
        ,Z.lastReceived
    from UnitMaxLenData UML 
    inner join -- THIS IS USED TO GET QTY FOR DEEP STORAGE
    (select ob_Items_RID, longlength, sum(UMStock) as StockForLength,  max(dateReceived) as lastReceived 
    from Units where UMStock > 0 and unitType = 'I' and lostFlag = 0
    group by ob_Items_RID, longlength ) as Z on Z.ob_Items_RID = UML.ob_Item_RID and Z.longLength = UML.maxLength) 
        as w on W.ob_Item_RID = I.ID and W.maxLength = M.maxLength
    
    where U.UMStock > 0 and U.unitType = 'I' and bayName is not null and U.lostflag = 0 
    and U.location not in (select Bay from AutoBayExclusionList)
    and U.unit not in (select unit from AutoBayTransactions)
    --and I.oldcode = '02L4.'
    group by I.ID, oldCode, U.longLength, M.inchesHigh, U.dateReceived, bayname
    order by max(ISNULL(TDS.unit,0)) desc, 4 desc, I.oldCode, U.longLength, U.dateReceived desc

    

OPEN myCursor 
FETCH NEXT FROM mycursor INTO @rowNo, @ID, @oldCode, @noUnits, @maxLen, @inchesHigh, @dateReceived,  @bayNames, @runningTotalUM,  @toDeep, @lastReceived, @east1WestMinus1, @eastWestMsg, @TDSUnit
WHILE @@FETCH_STATUS = 0  
BEGIN 
    set @bay = null
    
    -- 1ST, IF RUNNING TOTAL <= TODEEP AND BAY IS VALID ONE FOR DEEP STORAGE THEN SEE IF DEEP STORAGE AVAILABLE

    if @TDSUnit >  0 and 1 = 2
    --(@toDeep >= @runningTotalUM and @rowno > 2 AND CHARINDEX(@bayNames, @deepBays) > 0) and @dateReceived = @lastReceived 
    BEGIN
    
      -- SEE IF THERE IS A BAY WHERE THIS ITEM ALREADY IS
    select top 1 @bay = B.bay, @available = B.availableInches 
    from BayTotals B INNER JOIN AutoBayTransactions A on B.bay = A.bay 
    where B.maxLen = @maxLen AND
        A.oldCode = @oldCode AND
        B.availableInches >= ROUND(@noUnits * @inchesHigh,0)
        and B.deepStorage = 1
    order by B.availableInches - ROUND(@noUnits * @inchesHigh,0) desc, B.noUnits
    
    IF @bay IS NOT NULL BEGIN
        -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO SAME DEEP BAY
        INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], unit, [noUnits], [inchesUsed], [comment], dateReceived, bayNames)
        select @oldCode, @bay, @maxLen, unit, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'Existing Deep Bay', @dateReceived, @bayNames
            from Units U where U.ob_Items_RID = @ID and U.longlength = @maxLen and U.dateReceived = @dateReceived
                and U.UMStock > 0 and U.unitType = 'I' and U.lostflag = 0 and U.location not in (select Bay from AutoBayExclusionList)
    
        set @sameBay = @sameBay + 1
    
        -- UPDATE THE BAY
        Update BayTotals set noUnits = noUnits + @noUnits, 
        totInches = totInches + ROUND(@noUnits * @inchesHigh,0), 
        availableInches = availableInches - ROUND(@noUnits * @inchesHigh,0)
        WHERE BayTotals.bay = @bay
        
        END -- END OF IF SAME BAY
      
    IF @bay IS NULL BEGIN    
        -- SEE IF THERE IS A NEW BAY FOR THIS QTY
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B 
        where B.maxLen = @maxLen AND
            B.availableInches >= ROUND(@noUnits * @inchesHigh,0) and  
            B.deepStorage = 1 
        order by B.availableInches - ROUND(@noUnits * @inchesHigh,0) desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
        -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], unit, [noUnits], [inchesUsed], [comment], dateReceived, bayNames)
            select @oldCode, @bay, @maxLen, unit, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'New Deep Bay', @dateReceived, @bayNames
                from Units U where U.ob_Items_RID = @ID and U.longlength = @maxLen and U.dateReceived = @dateReceived
                    and U.UMStock > 0 and U.unitType = 'I' and U.lostflag = 0 and U.location not in (select Bay from AutoBayExclusionList)        
            
            set @newBay = @newBay + 1
        
            -- UPDATE THE BAY
           Update BayTotals set noUnits = noUnits + @noUnits, 
            totInches = totInches + ROUND(@noUnits * @inchesHigh,0), 
            availableInches = availableInches - ROUND(@noUnits * @inchesHigh,0)
            WHERE BayTotals.bay = @bay
            
            END -- END NEW BAY
        END -- END IF @bay IS NULL
        

    IF @bay IS NULL BEGIN
        -- SEE IF THERE IS A BAY + 2"
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B 
        where ABS(B.maxLen - @maxLen) <= 2 AND
            B.maxLen > @maxLen AND
            B.availableInches >= ROUND(@noUnits * @inchesHigh,0) AND
            B.deepStorage = 1
            and (left(B.bay,1) = LEFT(@baynames,1) OR left(B.bay,1) = RIGHT(@bayNames,1))
        order by B.availableInches - ROUND(@noUnits * @inchesHigh,0) desc, noUnits
        
        IF @bay IS NOT NULL BEGIN
        -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], unit, [noUnits], [inchesUsed], [comment], dateReceived, bayNames)
                select @oldCode, @bay, @maxLen, unit, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'Deep Delta Max Len', @dateReceived, @bayNames
                    from Units U where U.ob_Items_RID = @ID and U.longlength = @maxLen and U.dateReceived = @dateReceived
                        and U.UMStock > 0 and U.unitType = 'I' and U.lostflag = 0 and U.location not in (select Bay from AutoBayExclusionList)        
            
            set @deltaLen = @deltaLen + 1
        
            -- UPDATE THE BAY
           Update BayTotals set noUnits = noUnits + @noUnits, 
            totInches = totInches + ROUND(@noUnits * @inchesHigh,0), 
            availableInches = availableInches - ROUND(@noUnits * @inchesHigh,0)
            WHERE BayTotals.bay = @bay
            
            END -- END NEW BAY
        END -- END IF @bay IS NULL          
             
    END -- IF (@toDeep)
    
    -- SEE IF THERE IS A BAY WHERE THIS ITEM ALREADY IS
    IF @bay IS NULL BEGIN 
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B INNER JOIN AutoBayTransactions A on B.bay = A.bay 
        where B.maxLen = @maxLen AND
            A.oldCode = @oldCode AND
            B.availableInches >= ROUND(@noUnits * @inchesHigh,0)
            and B.deepStorage = 0
        order by B.eastFactor * @east1WestMinus1 desc, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
            -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO SAME BAY
            INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], unit, [noUnits], [inchesUsed], [comment], dateReceived, bayNames)
            select @oldCode, @bay, @maxLen, unit, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'Existing Bay ' + @eastWestMsg, @dateReceived, @bayNames
                from Units U where U.ob_Items_RID = @ID and U.longlength = @maxLen and U.dateReceived = @dateReceived
                    and U.UMStock > 0 and U.unitType = 'I' and U.lostflag = 0 and U.location not in (select Bay from AutoBayExclusionList)        
            set @sameBay = @sameBay + 1
        
            -- UPDATE THE BAY
            Update BayTotals set noUnits = noUnits + @noUnits, 
            totInches = totInches + ROUND(@noUnits * @inchesHigh,0), 
            availableInches = availableInches - ROUND(@noUnits * @inchesHigh,0)
            WHERE BayTotals.bay = @bay
            
            END -- END OF IF SAME BAY
        END -- IF BAY IS NULL
    
    
    IF @bay IS NULL BEGIN    
        -- SEE IF THERE IS A NEW BAY FOR THIS QTY
        select top 1 @bay = B.bay, @available = B.availableInches
        from BayTotals B 
        where B.maxLen = @maxLen AND
            B.availableInches >= ROUND(@noUnits * @inchesHigh,0) and  
            (left(B.bay,1) = Left(@baynames,1) or left(B.bay,1) = right(@baynames,1)) AND
            --@preferredAisle = B.aisle AND
            B.deepStorage <> 1 
        order by --(B.eastFactor * @east1WestMinus1) 
        case when (B.eastFactor = 1 and @east1WestMinus1 = 1) OR B.eastFactor = -1 and @east1WestMinus1 = -1 then 1 when @east1WestMinus1 = 0 then 2 else 3 end, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
        -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], unit, [noUnits], [inchesUsed], [comment], dateReceived, bayNames)
            select @oldCode, @bay, @maxLen, unit, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'New Bay ' + @eastWestMsg , @dateReceived, @bayNames
                from Units U where U.ob_Items_RID = @ID and U.longlength = @maxLen and U.dateReceived = @dateReceived
                    and U.UMStock > 0 and U.unitType = 'I' and U.lostflag = 0 and U.location not in (select Bay from AutoBayExclusionList)        
        
            set @newBay = @newBay + 1
        
            -- UPDATE THE BAY
           Update BayTotals set noUnits = noUnits + @noUnits, 
            totInches = totInches + ROUND(@noUnits * @inchesHigh,0), 
            availableInches = availableInches - ROUND(@noUnits * @inchesHigh,0)
            WHERE BayTotals.bay = @bay
            
            END -- END NEW BAY
        END -- END IF @bay IS NULL
 
      
      
      
      
      
    IF @bay IS NULL BEGIN
        -- SEE IF THERE IS A BAY + 2"
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B 
        where B.maxLen - @maxLen <= 2 AND
            B.maxLen >= @maxLen AND
            B.availableInches >= ROUND(@noUnits * @inchesHigh,0) AND
            B.deepStorage <> 1
            and (left(B.bay,1) = LEFT(@baynames,1) OR left(B.bay,1) = RIGHT(@bayNames,1))
        order by --(B.eastFactor * @east1WestMinus1) 
        case when (B.eastFactor = 1 and @east1WestMinus1 = 1) OR B.eastFactor = -1 and @east1WestMinus1 = -1 then 1 when @east1WestMinus1 = 0 then 2 else 3 end, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
        -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], unit, [noUnits], [inchesUsed], [comment], dateReceived, bayNames)
            select @oldCode, @bay, @maxLen, unit, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'Delta Max Len ' + @eastWestMsg, @dateReceived, @bayNames
                from Units U where U.ob_Items_RID = @ID and U.longlength = @maxLen and U.dateReceived = @dateReceived
                    and U.UMStock > 0 and U.unitType = 'I' and U.lostflag = 0  and U.location not in (select Bay from AutoBayExclusionList)       
        
            set @deltaLen = @deltaLen + 1
        
            -- UPDATE THE BAY
           Update BayTotals set noUnits = noUnits + @noUnits, 
            totInches = totInches + ROUND(@noUnits * @inchesHigh,0), 
            availableInches = availableInches - ROUND(@noUnits * @inchesHigh,0)
            WHERE BayTotals.bay = @bay
            
            END -- END NEW BAY
        END -- END IF @bay IS NULL          
      

    IF @bay IS NULL BEGIN
        -- SEE IF THERE IS A ALTERNATE BAY
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B 
        where ABS(B.maxLen - @maxLen) <= 2 AND
            B.availableInches >= ROUND(@noUnits * @inchesHigh,0) AND
            B.deepStorage <> 1
            AND ((left(@baynames,1) = '3' AND left(b.bay,1) = '4')
                OR (left(@baynames,1) = '4' AND left(b.bay,1) = '3')
                OR (CHARINDEX(left(@baynames,1), 'E, F, G, H, I, J, K, L') > 0 AND
                CHARINDEX(left(B.bay,1), 'E, F, G, H, I, J, K, L') > 0))
        order by --(B.eastFactor * @east1WestMinus1) 
        case when (B.eastFactor = 1 and @east1WestMinus1 = 1) OR B.eastFactor = -1 and @east1WestMinus1 = -1 then 1 when @east1WestMinus1 = 0 then 2 else 3 end, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
        -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], unit, [noUnits], [inchesUsed], [comment], dateReceived, bayNames)
            select @oldCode, @bay, @maxLen, unit, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'Alternate Bay ' + @eastWestMsg, @dateReceived, @bayNames
                from Units U where U.ob_Items_RID = @ID and U.longlength = @maxLen and U.dateReceived = @dateReceived
                    and U.UMStock > 0 and U.unitType = 'I' and U.lostflag = 0 and U.location not in (select Bay from AutoBayExclusionList)        
        
            set @deltaLen = @deltaLen + 1
        
            -- UPDATE THE BAY
           Update BayTotals set noUnits = noUnits + @noUnits, 
            totInches = totInches + ROUND(@noUnits * @inchesHigh,0), 
            availableInches = availableInches - ROUND(@noUnits * @inchesHigh,0)
            WHERE BayTotals.bay = @bay
            
            END -- END NEW BAY
        END -- END IF @bay IS NULL          
      



     
    IF @bay IS NULL BEGIN
        INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], [unit], noUnits, [inchesUsed], [comment], dateReceived, bayNames)
            select @oldCode, 'NONE', @maxLen, unit, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'NO FIT!!', @dateReceived, @bayNames
                from Units U where U.ob_Items_RID = @ID and U.longlength = @maxLen and U.dateReceived = @dateReceived
                    and U.UMStock > 0 and U.unitType = 'I' and U.lostflag = 0 and U.location not in (select Bay from AutoBayExclusionList)        
        
        set @noBay = @noBay + 1
        END -- END IF @bay IS NULL
    
FETCH NEXT FROM mycursor INTO @rowNo, @ID, @oldCode,  @noUnits, @maxLen, @inchesHigh, @dateReceived,  @bayNames, @runningTotalUM, @toDeep, @lastReceived, @east1WestMinus1, @eastWestMsg, @TDSUnit
           
END 

CLOSE mycursor  
DEALLOCATE mycursor 


Update BayTotals set availFeetInches = dbo.inchesToFeet(availableInches)

/*
Update BayTotals set noItems = Z.noItems
from BayTotals B inner join 
(select bay, count(distinct oldcode) as noItems from autobayTransactions group by bay) as Z on B.bay = Z.bay
*/
--select @newBay as newBay, @sameBay as SameBay, @deltaLen as DeltaLen, @noBay as NOBay

/*
select row_number() over (order by A.recID) as rowno, A.oldCode as code, A.itemMaxLen as maxLen, internalDescription as item, A.dateReceived, A.bayNames, A.bay, U.location as oldBay, A.noUnits, A.unit, A.inchesUsed, A.comment

from autoBayTransactions A inner join Items I on A.oldCode = I.oldCode
inner join Units U on A.unit = U.unit
--where bay = 'F02'
--where comment = 'NO FIT!!'
order by A.oldCode, A.itemMaxLen, A.dateReceived
*/
--select count(*) from AutoBayTransactions where comment = 'NO FIT!!'



delete from autobaytransactions where bay = 'NONE'



    

;
/*
with w as (select UML.ob_Item_RID, UML.maxLength,
    stockForLength, @noMonthsDeep * UML.monthlyUsage as Usage3M,
    case when @noMonthsDeep * UML.monthlyUsage >= StockForLength then 0 else 
        StockForLength - (@noMonthsDeep * UML.monthlyUsage) end as ToDeep
    from UnitMaxLenData UML 
    inner join (select ob_Items_RID, longlength, sum(UMStock) as StockForLength 
    from Units where UMStock > 0 and unitType = 'I'
    group by ob_Items_RID, longlength) as Z on Z.ob_Items_RID = UML.ob_Item_RID and Z.longLength = UML.maxLength)
*/
  
 
        
        
DECLARE myCursor CURSOR FOR   


select row_number()  over (partition by I.ID, U.longLength
        order by I.ID, U.longLength, U.dateReceived) as rowno,
    I.ID, I.oldCode, U.unit, 1 as noUnits,  U.longLength, M.inchesHigh, U.dateReceived, bayName,
        sum(U.UMStock) over (partition by U.ob_Items_RID, U.longLength
        order by U.ob_Items_RID, U.longLength, U.dateReceived desc, U.unit desc) as runningTotalUM,    
        W.toDeep as toDeep, W.lastReceived as lastReceived,
    case when UD.location IS NULL THEN 0 
    when left(UD.location,1) >= '1' and left(UD.location,1) <= '5' then -1 
    when left(UD.location,1) = '0' OR (left(UD.location,1) >= '6' and left(UD.location,1) <= '9') then 1 else 0 end as East1WestMinus1,
    case when UD.location IS NULL THEN '' 
    when left(UD.location,1) >= '1' and left(UD.location,1) <= '5' then ' Want WEST' 
    when left(UD.location,1) = '0' OR (left(UD.location,1) >= '6' and left(UD.location,1) <= '9') then 'Want EAST' else '' end as EastWestMsg
    from Units U inner join Items I on U.ob_Items_RID = I.ID    
    inner join  UnitMaxLenData M  on M.ob_Item_RID = U.ob_Items_RID and M.maxLength = U.longLength
    -- USED TO GET EAST OR WEST
    left outer join UnDigByMaxLen UD on UD.ob_Items_RID = I.ID and UD.maxlen = U.longLength
    inner join (select UML.ob_Item_RID, UML.maxLength,
    stockForLength, case when bayName = 'A-B' then 2 else 1 end * @noMonthsDeep * UML.monthlyUsage as Usage3M,
    case when case when bayName = 'A-B' then 2 else 1 end * @noMonthsDeep * UML.monthlyUsage >= StockForLength OR UML.stdReceivedUnitSize * 2 >= StockForLength then 0  
        else StockForLength - (case when bayName = 'A-B' then 2 else 1 end * @noMonthsDeep * UML.monthlyUsage) end as ToDeep
        ,Z.lastReceived
    from UnitMaxLenData UML 
    inner join -- THIS IS USED TO GET QTY FOR DEEP STORAGE
    (select ob_Items_RID, longlength, sum(UMStock) as StockForLength,  max(dateReceived) as lastReceived 
    from Units where UMStock > 0 and unitType = 'I'
    group by ob_Items_RID, longlength ) as Z on Z.ob_Items_RID = UML.ob_Item_RID and Z.longLength = UML.maxLength) 
        as w on W.ob_Item_RID = I.ID and W.maxLength = M.maxLength
    
    where U.UMStock > 0 and U.unitType = 'I' and bayName is not null and U.lostflag = 0 
    and U.unit not in (select Unit from AutoBayTransactions)
    and U.location not in (select bay from AutoBayExclusionList)
    --and I.oldcode = '02L4.'
--    group by I.ID, oldCode, U.longLength, M.inchesHigh, bayname
    order by I.oldCode, U.longLength, U.dateReceived desc

    

OPEN myCursor 
FETCH NEXT FROM mycursor INTO @rowNo, @ID, @oldCode, @unit, @noUnits, @maxLen, @inchesHigh, @dateReceived,  @bayNames, @runningTotalUM,  @toDeep, @lastReceived, @east1WestMinus1, @eastWestMsg
WHILE @@FETCH_STATUS = 0  
BEGIN 
    set @bay = null
    
    -- 1ST, IF RUNNING TOTAL <= TODEEP AND BAY IS VALID ONE FOR DEEP STORAGE THEN SEE IF DEEP STORAGE AVAILABLE
/*
    if (@toDeep >= @runningTotalUM and @rowno > 2 AND CHARINDEX(@bayNames, @deepBays) > 0) and @dateReceived = @lastReceived BEGIN
    
      -- SEE IF THERE IS A BAY WHERE THIS ITEM ALREADY IS
    select top 1 @bay = B.bay, @available = B.availableInches 
    from BayTotals B INNER JOIN AutoBayTransactions A on B.bay = A.bay 
    where B.maxLen = @maxLen AND
        A.oldCode = @oldCode AND
        B.availableInches >= ROUND(@noUnits * @inchesHigh,0)
        and B.deepStorage = 1
    order by B.availableInches - ROUND(@noUnits * @inchesHigh,0) desc, B.noUnits
    
    IF @bay IS NOT NULL BEGIN
        -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO SAME DEEP BAY
        INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], unit, [noUnits], [inchesUsed], [comment], dateReceived, bayNames)
        select @oldCode, @bay, @maxLen, unit, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'Existing Deep Bay', @dateReceived, @bayNames
            from Units U where U.ob_Items_RID = @ID and U.longlength = @maxLen and U.dateReceived = @dateReceived
                and U.UMStock > 0 and U.unitType = 'I' and U.lostflag = 0 
    
        set @sameBay = @sameBay + 1
    
        -- UPDATE THE BAY
        Update BayTotals set noUnits = noUnits + @noUnits, 
        totInches = totInches + ROUND(@noUnits * @inchesHigh,0), 
        availableInches = availableInches - ROUND(@noUnits * @inchesHigh,0)
        WHERE BayTotals.bay = @bay
        
        END -- END OF IF SAME BAY
      
    IF @bay IS NULL BEGIN    
        -- SEE IF THERE IS A NEW BAY FOR THIS QTY
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B 
        where B.maxLen = @maxLen AND
            B.availableInches >= ROUND(@noUnits * @inchesHigh,0) and  
            B.deepStorage = 1 
        order by B.availableInches - ROUND(@noUnits * @inchesHigh,0) desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
        -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], unit, [noUnits], [inchesUsed], [comment], dateReceived, bayNames)
            select @oldCode, @bay, @maxLen, unit, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'New Deep Bay', @dateReceived, @bayNames
                from Units U where U.ob_Items_RID = @ID and U.longlength = @maxLen and U.dateReceived = @dateReceived
                    and U.UMStock > 0 and U.unitType = 'I' and U.lostflag = 0         
            
            set @newBay = @newBay + 1
        
            -- UPDATE THE BAY
           Update BayTotals set noUnits = noUnits + @noUnits, 
            totInches = totInches + ROUND(@noUnits * @inchesHigh,0), 
            availableInches = availableInches - ROUND(@noUnits * @inchesHigh,0)
            WHERE BayTotals.bay = @bay
            
            END -- END NEW BAY
        END -- END IF @bay IS NULL
        

    IF @bay IS NULL BEGIN
        -- SEE IF THERE IS A BAY + 2"
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B 
        where B.maxLen - @maxLen <= 2 AND
            B.availableInches >= ROUND(@noUnits * @inchesHigh,0) AND
            B.deepStorage = 1
            and (left(B.bay,1) = LEFT(@baynames,1) OR left(B.bay,1) = RIGHT(@bayNames,1))
        order by B.availableInches - ROUND(@noUnits * @inchesHigh,0) desc, noUnits
        
        IF @bay IS NOT NULL BEGIN
        -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], unit, [noUnits], [inchesUsed], [comment], dateReceived, bayNames)
                select @oldCode, @bay, @maxLen, unit, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'Deep Delta Max Len', @dateReceived, @bayNames
                    from Units U where U.ob_Items_RID = @ID and U.longlength = @maxLen and U.dateReceived = @dateReceived
                        and U.UMStock > 0 and U.unitType = 'I' and U.lostflag = 0         
            
            set @deltaLen = @deltaLen + 1
        
            -- UPDATE THE BAY
           Update BayTotals set noUnits = noUnits + @noUnits, 
            totInches = totInches + ROUND(@noUnits * @inchesHigh,0), 
            availableInches = availableInches - ROUND(@noUnits * @inchesHigh,0)
            WHERE BayTotals.bay = @bay
            
            END -- END NEW BAY
        END -- END IF @bay IS NULL          
             
    END -- IF (@toDeep)
*/    
    -- SEE IF THERE IS A BAY WHERE THIS ITEM ALREADY IS
    IF @bay IS NULL BEGIN 
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B INNER JOIN AutoBayTransactions A on B.bay = A.bay 
        where B.maxLen = @maxLen AND
            A.oldCode = @oldCode AND
            B.availableInches >= ROUND(@noUnits * @inchesHigh,0)
            and B.deepStorage = 0
        order by --(B.eastFactor * @east1WestMinus1) 
        case when (B.eastFactor = 1 and @east1WestMinus1 = 1) OR B.eastFactor = -1 and @east1WestMinus1 = -1 then 1 when @east1WestMinus1 = 0 then 2 else 3 end, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
            -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO SAME BAY
            INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], unit, [noUnits], [inchesUsed], [comment], dateReceived, bayNames)
            select @oldCode, @bay, @maxLen, @unit, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'Existing Bay', @dateReceived, @bayNames
            set @sameBay = @sameBay + 1
        
            -- UPDATE THE BAY
            Update BayTotals set noUnits = noUnits + @noUnits, 
            totInches = totInches + ROUND(@noUnits * @inchesHigh,0), 
            availableInches = availableInches - ROUND(@noUnits * @inchesHigh,0)
            WHERE BayTotals.bay = @bay
            
            END -- END OF IF SAME BAY
        END -- IF BAY IS NULL
    
    
    IF @bay IS NULL BEGIN    
        -- SEE IF THERE IS A NEW BAY FOR THIS QTY
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B 
        where B.maxLen = @maxLen AND
            B.availableInches >= ROUND(@noUnits * @inchesHigh,0) and  
            (left(B.bay,1) = Left(@baynames,1) or left(B.bay,1) = right(@baynames,1)) AND
            --@preferredAisle = B.aisle AND
            B.deepStorage <> 1 
        order by --(B.eastFactor * @east1WestMinus1) 
        case when (B.eastFactor = 1 and @east1WestMinus1 = 1) OR B.eastFactor = -1 and @east1WestMinus1 = -1 then 1 when @east1WestMinus1 = 0 then 2 else 3 end, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
        -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], unit, [noUnits], [inchesUsed], [comment], dateReceived, bayNames)
            select @oldCode, @bay, @maxLen, @unit, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'New Bay' + @eastWestMsg, @dateReceived, @bayNames
        
            set @newBay = @newBay + 1
        
            -- UPDATE THE BAY
           Update BayTotals set noUnits = noUnits + @noUnits, 
            totInches = totInches + ROUND(@noUnits * @inchesHigh,0), 
            availableInches = availableInches - ROUND(@noUnits * @inchesHigh,0)
            WHERE BayTotals.bay = @bay
            
            END -- END NEW BAY
        END -- END IF @bay IS NULL
 
      
      
    IF @bay IS NULL BEGIN
        -- SEE IF THERE IS A BAY + 2"
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B 
        where B.maxLen - @maxLen <= 2 AND
            B.maxLen >= @maxLen AND
            B.availableInches >= ROUND(@noUnits * @inchesHigh,0) AND
            B.deepStorage <> 1
            and (left(B.bay,1) = LEFT(@baynames,1) OR left(B.bay,1) = RIGHT(@bayNames,1))
        order by --(B.eastFactor * @east1WestMinus1) 
        case when (B.eastFactor = 1 and @east1WestMinus1 = 1) OR B.eastFactor = -1 and @east1WestMinus1 = -1 then 1 when @east1WestMinus1 = 0 then 2 else 3 end, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
        -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], unit, [noUnits], [inchesUsed], [comment], dateReceived, bayNames)
            select @oldCode, @bay, @maxLen, @unit, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'Delta Max Len ' + @eastWestMsg, @dateReceived, @bayNames
        
            set @deltaLen = @deltaLen + 1
        
            -- UPDATE THE BAY
           Update BayTotals set noUnits = noUnits + @noUnits, 
            totInches = totInches + ROUND(@noUnits * @inchesHigh,0), 
            availableInches = availableInches - ROUND(@noUnits * @inchesHigh,0)
            WHERE BayTotals.bay = @bay
            
            END -- END NEW BAY
        END -- END IF @bay IS NULL          
      

      
    IF @bay IS NULL BEGIN
        -- SEE IF THERE IS A ALTERNATE BAY
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B 
        where ABS(B.maxLen - @maxLen) <= 2 AND
            B.availableInches >= ROUND(@noUnits * @inchesHigh,0) AND
            B.deepStorage <> 1
            AND ((left(@baynames,1) = '3' AND left(b.bay,1) = '4')
                OR (left(@baynames,1) = '4' AND left(b.bay,1) = '3')
                OR (CHARINDEX(left(@baynames,1), 'E, F, G, H, I, J, K, L') > 0 AND
                CHARINDEX(left(B.bay,1), 'E, F, G, H, I, J, K, L') > 0))
        order by --(B.eastFactor * @east1WestMinus1) 
        case when (B.eastFactor = 1 and @east1WestMinus1 = 1) OR B.eastFactor = -1 and @east1WestMinus1 = -1 then 1 when @east1WestMinus1 = 0 then 2 else 3 end, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
        -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], unit, [noUnits], [inchesUsed], [comment], dateReceived, bayNames)
            select @oldCode, @bay, @maxLen, @unit, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'Existing Bay ' + @eastWestMsg, @dateReceived, @bayNames
        
            set @deltaLen = @deltaLen + 1
        
            -- UPDATE THE BAY
           Update BayTotals set noUnits = noUnits + @noUnits, 
            totInches = totInches + ROUND(@noUnits * @inchesHigh,0), 
            availableInches = availableInches - ROUND(@noUnits * @inchesHigh,0)
            WHERE BayTotals.bay = @bay
            
            END -- END NEW BAY
        END -- END IF @bay IS NULL          
      
     
    IF @bay IS NULL BEGIN
        INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], [unit], noUnits, [inchesUsed], [comment], dateReceived, bayNames)
            select @oldCode, 'NONE', @maxLen, @unit, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'NO FIT!!', @dateReceived, @bayNames
        
        set @noBay = @noBay + 1
        END -- END IF @bay IS NULL
    
FETCH NEXT FROM mycursor INTO @rowNo, @ID, @oldCode,  @unit, @noUnits, @maxLen, @inchesHigh, @dateReceived,  @bayNames, @runningTotalUM, @toDeep, @lastReceived, @east1WestMinus1, @eastWestMsg
           
END 

CLOSE mycursor  
DEALLOCATE mycursor 


Update BayTotals set availFeetInches = dbo.inchesToFeet(availableInches)

Update BayTotals set noItems = Z.noItems
from BayTotals B inner join 
(select bay, count(distinct oldcode) as noItems from autobayTransactions group by bay) as Z on B.bay = Z.bay

--select @newBay as newBay, @sameBay as SameBay, @deltaLen as DeltaLen, @noBay as NOBay


select A.oldCode as code, A.itemMaxLen as maxLen, internalDescription as item, A.dateReceived,  A.bay, U.location as oldBay, 
 A.unit, isNull(UD.location,'') as unDigTo

from autoBayTransactions A inner join Items I on A.oldCode = I.oldCode
left outer join UndigByMaxLen as UD on UD.ob_Items_RID = I.ID and UD.maxLen = A.itemMaxLen
inner join Units U on A.unit = U.unit
--where comment = 'NO FIT!!' 
order by A.oldCode, A.itemMaxLen, A.dateReceived

--select count(*) from AutoBayTransactions where comment = 'NO FIT!!'
GO
