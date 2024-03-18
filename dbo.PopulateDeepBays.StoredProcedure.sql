USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[PopulateDeepBays]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PopulateDeepBays]

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
        @noUnits        integer = 1,
        @inchesHigh     integer,
        @dateReceived   date,
        --@preferredAisle varchar(6),
        @bayNames       varchar(4),
        @runningTotalUM integer,
        @monthsStock    integer,
        @toDeep         integer,
        @unit           integer,
        @rowno          integer,
        @lastReceived   date,
        @east1WestMinus1    integer,
        @eastWestMsg    varchar(10)
        
-- TEMP VARIABLES
Declare @bay            varchar(6),
        @available      integer,
        @newBay         integer = 0,
        @sameBay        integer = 0,
        @deltaLen       integer = 0,
        @noBay          integer = 0,
        @noMonthsDeep   integer = 4
    
    

;
/*
with w as (select AisleName, maxLen, totAvail, isNull(totNeeded,0) as totNeeded,
case when isNull(totNeeded,0) <= totAvail then 0
else isNull(totNeeded,0) - totAvail end as toDeep

from (select A.aisleName, maxLen, sum(inchesHigh) as totAvail
from BayTotals B inner join Aisles A on left(b.bay,1) = a.leftBank or left(b.bay,1) = A.rightBank
where B.deepStorage = 0
group by aisleName, maxLen) as Y
left outer join 

-- THIS QUERY GETS THE DEMAND BY BAY / MAXLENGTH
(select bayName, maxLength, sum(inchesHigh) as totNeeded from
(select UML.bayName, UML.maxLength, UML.inchesHigh
    from Units U inner join Items I on U.ob_Items_RID = I.ID
    inner join UnitMaxLenData UML on UML.ob_Item_RID = I.ID and UML.maxLength = U.longLength      
    where U.UMStock > 0 and U.unitType = 'I' and U.lostFlag = 0 and bayname is not null) as Z
    group by bayName, maxlength) as W on Y.aisleName = W.bayname and Y.maxLen = W.maxLength
 
where isNull(totNeeded,0) > totAvail)    
*/


DECLARE myCursor CURSOR FOR   
select
    ID, oldcode, unit, longlength, incheshigh, datereceived, bayname, runningTotalUM, monthsStock, toDeep
from     
(select 
    I.ID, I.oldCode, U.unit,  U.longLength, M.inchesHigh, U.dateReceived, bayName,
        sum(M.inchesHigh) over (partition by bayName, U.longLength 
        order by case when M.monthlyUsage = 0 then 0 else round(StockForLength / M.MonthlyUsage,1) end desc,
        U.dateReceived desc, U.unit desc) as runningTotalUM,    
        case when M.monthlyUsage = 0 then 0 else round(StockForLength / M.MonthlyUsage,1) end as monthsStock,
        W.toDeep
    from Units U inner join Items I on U.ob_Items_RID = I.ID    
    inner join  UnitMaxLenData M  on M.ob_Item_RID = U.ob_Items_RID and M.maxLength = U.longLength

    inner join -- THIS IS USED TO GET QTY FOR DEEP STORAGE
    (select ob_Items_RID, longlength, sum(UMStock) as StockForLength,  max(dateReceived) as lastReceived 
    from Units where UMStock > 0 and unitType = 'I' and lostFlag = 0
    group by ob_Items_RID, longlength ) as Z on Z.ob_Items_RID = M.ob_Item_RID and Z.longLength = M.maxLength
    inner join  ((select AisleName, maxLen, totAvail, isNull(totNeeded,0) as totNeeded,
case when isNull(totNeeded,0) <= totAvail then 0
else isNull(totNeeded,0) - totAvail end as toDeep

from (select A.aisleName, maxLen, sum(inchesHigh) as totAvail
from BayTotals B inner join Aisles A on left(b.bay,1) = a.leftBank or left(b.bay,1) = A.rightBank
where B.deepStorage = 0


group by aisleName, maxLen) as Y
left outer join 

-- THIS QUERY GETS THE DEMAND BY BAY / MAXLENGTH
(select bayName, maxLength, sum(inchesHigh) as totNeeded from
(select UML.bayName, UML.maxLength, UML.inchesHigh
    from Units U inner join Items I on U.ob_Items_RID = I.ID
    inner join UnitMaxLenData UML on UML.ob_Item_RID = I.ID and UML.maxLength = U.longLength      
    where U.UMStock > 0 and U.unitType = 'I' and U.lostFlag = 0 and bayname is not null) as Z
    group by bayName, maxlength) as W on Y.aisleName = W.bayname and Y.maxLen = W.maxLength
 
where isNull(totNeeded,0) > totAvail))
    as W on W.aisleName = M.bayName and W.maxlen = U.longLength    
    
    where U.UMStock > 0 and U.unitType = 'I' and bayName is not null and U.lostflag = 0 
    and U.unit not in (select Unit from AutoBayTransactions)
    and U.location not in (select Bay from AutoBayExclusionList)) as Q 
    where runningTotalUM <= toDeep
    order by monthsStock desc, 
    oldCode, longLength, dateReceived desc

  

OPEN myCursor 
FETCH NEXT FROM mycursor INTO @ID, @oldCode, @unit,  @maxLen, @inchesHigh, @dateReceived,  @bayNames, @runningTotalUM,  @monthsStock, @toDeep 
WHILE @@FETCH_STATUS = 0  
BEGIN 
    set @bay = null    

    
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
            from Units U where U.ob_Items_RID = @ID and U.longlength = @maxLen and U.unit = @unit
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
                from Units U where U.ob_Items_RID = @ID and U.longlength = @maxLen and U.unit = @unit
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
            B.maxLen >= @maxLen AND
            B.availableInches >= ROUND(@noUnits * @inchesHigh,0) AND
            B.deepStorage = 1
            and (left(B.bay,1) = LEFT(@baynames,1) OR left(B.bay,1) = RIGHT(@bayNames,1))
        order by B.availableInches - ROUND(@noUnits * @inchesHigh,0) desc, noUnits
        
        IF @bay IS NOT NULL BEGIN
        -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], unit, [noUnits], [inchesUsed], [comment], dateReceived, bayNames)
                select @oldCode, @bay, @maxLen, unit, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'Deep Delta Max Len', @dateReceived, @bayNames
                    from Units U where U.ob_Items_RID = @ID and U.longlength = @maxLen and U.unit = @unit
                        and U.UMStock > 0 and U.unitType = 'I' and U.lostflag = 0         
            
            set @deltaLen = @deltaLen + 1
        
            -- UPDATE THE BAY
           Update BayTotals set noUnits = noUnits + @noUnits, 
            totInches = totInches + ROUND(@noUnits * @inchesHigh,0), 
            availableInches = availableInches - ROUND(@noUnits * @inchesHigh,0)
            WHERE BayTotals.bay = @bay
            
            END -- END NEW BAY
        END -- END IF @bay IS NULL          
           

    FETCH NEXT FROM mycursor INTO @ID, @oldCode, @unit,  @maxLen, @inchesHigh, @dateReceived,  @bayNames, @runningTotalUM,  @monthsStock, @toDeep
    end
 
CLOSE mycursor  
DEALLOCATE mycursor 


Update BayTotals set availFeetInches = dbo.inchesToFeet(availableInches) 

/*
select row_number() over (order by A.recID) as rowno, A.oldCode as code, A.itemMaxLen as maxLen, internalDescription as item, A.dateReceived, A.bayNames, A.bay, U.location as oldBay, 
A.noUnits, A.unit, A.inchesUsed, isNull(UD.location,'') as unDigTo, A.comment

from autoBayTransactions A inner join Items I on A.oldCode = I.oldCode
left outer join UndigByMaxLen as UD on UD.ob_Items_RID = I.ID and UD.maxLen = A.itemMaxLen
inner join Units U on A.unit = U.unit
--where comment = 'NO FIT!!' 
order by A.oldCode, A.itemMaxLen, A.dateReceived
*/
GO
