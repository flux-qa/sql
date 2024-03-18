USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[fee]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[fee]

as 


-- CONSTANTS
Declare
    @bayHeight          integer = 16 * 12,
    @bayDepth           integer = 4
    
-- CURSOR VARIABLES
Declare @ID             integer,
        @oldCode        varchar(6),
        @maxLen         integer,
        @noUnits        integer,
        @inchesHigh     integer,
        @dateReceived   date,
        @preferredAisle varchar(6),
        @bayNames       varchar(4)
        
-- TEMP VARIABLES
Declare @bay            varchar(6),
        @available      integer,
        @newBay         integer = 0,
        @sameBay        integer = 0,
        @deltaLen       integer = 0,
        @noBay          integer = 0
    
    
-- CLEAR THE BAY TOTALS
Update BayTotals set noUnits = 0, totUM = 0, totInches = 0, noItems = 0, availableInches = inchesHigh

delete from AutoBayTransactions

    
DECLARE myCursor CURSOR FOR 

select I.ID, I.oldCode, M.maxLength, Z.noUnits, M.inchesHigh, Z.dateReceived, preferredAisle,  bayName
    from  UnitMaxLenData M  inner join Items I on I.ID = M.ob_Item_RID
    inner join (select ob_Items_RID, longLength, dateReceived, count(*) as noUnits 
        from Units where UMStock > 0 and unitType = 'I' group by ob_Items_RID, longLength, dateReceived) as Z on Z.ob_Items_RID = I.ID and Z.longLength = M.maxlength
    where Z.noUnits > 0 and PreferredAisle is not null
    order by I.oldCode, M.maxLength
    


OPEN myCursor 
FETCH NEXT FROM mycursor INTO @ID, @oldCode, @maxLen, @noUnits, @inchesHigh, @dateReceived, @preferredAisle, @bayNames
WHILE @@FETCH_STATUS = 0  
BEGIN 
    set @bay = null
    
    -- SEE IF THERE IS A BAY WHERE THIS ITEM ALREADY IS
    select top 1 @bay = B.bay, @available = B.availableInches 
    from BayTotals B INNER JOIN AutoBayTransactions A on B.bay = A.bay 
    where B.maxLen = @maxLen AND
        A.oldCode = @oldCode AND
        B.availableInches >= ROUND(@noUnits * @inchesHigh,0)
        and B.deepStorage = 0
    order by B.availableInches - ROUND(@noUnits * @inchesHigh,0) desc, B.noUnits
    
    IF @bay IS NOT NULL BEGIN
        -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO SAME BAY
        INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], [noUnits], [inchesUsed], [comment], dateReceived, bayNames)
        select @oldCode, @bay, @maxLen, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'Existing Bay', @dateReceived, @bayNames
    
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
            B.availableInches >= ROUND(@noUnits * @inchesHigh,0) and  @preferredAisle = B.aisle AND
            B.deepStorage <> 1 AND B.aisle = @preferredAisle
        order by B.availableInches - ROUND(@noUnits * @inchesHigh,0) desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
        -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], [noUnits], [inchesUsed], [comment], dateReceived, bayNames)
            select @oldCode, @bay, @maxLen, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'New Bay', @dateReceived, @bayNames
        
            set @newBay = @newBay + 1
        
            -- UPDATE THE BAY
           Update BayTotals set noUnits = noUnits + @noUnits, 
            totInches = totInches + ROUND(@noUnits * @inchesHigh,0), 
            availableInches = availableInches - ROUND(@noUnits * @inchesHigh,0)
            WHERE BayTotals.bay = @bay
            
            END -- END NEW BAY
        END -- END IF @bay IS NULL
      
    IF @bay IS NULL BEGIN
        -- SEE IF THERE IS A BAY +/- 2"
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B 
        where ABS(B.maxLen - @maxLen) <= 2 AND
            B.availableInches >= ROUND(@noUnits * @inchesHigh,0) AND
            B.deepStorage <> 1
            and B.aisle = @preferredAisle
        order by B.availableInches - ROUND(@noUnits * @inchesHigh,0) desc, noUnits
        
        IF @bay IS NOT NULL BEGIN
        -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], [noUnits], [inchesUsed], [comment], dateReceived, bayNames)
            select @oldCode, @bay, @maxLen, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'Delta MaxLen', @dateReceived, @bayNames
        
            set @deltaLen = @deltaLen + 1
        
            -- UPDATE THE BAY
           Update BayTotals set noUnits = noUnits + @noUnits, 
            totInches = totInches + ROUND(@noUnits * @inchesHigh,0), 
            availableInches = availableInches - ROUND(@noUnits * @inchesHigh,0)
            WHERE BayTotals.bay = @bay
            
            END -- END NEW BAY
        END -- END IF @bay IS NULL          
      
      
      
    IF @bay IS NULL BEGIN
        INSERT INTO [dbo].[AutoBayTransactions]([oldCode], [bay], [itemMaxLen], [noUnits], [inchesUsed], [comment], dateReceived, bayNames)
            select @oldCode, 'NONE', @maxLen, @noUnits, ROUND(@noUnits * @inchesHigh,0), 'NO FIT!!', @dateReceived, @bayNames
        
        set @noBay = @noBay + 1
        END -- END IF @bay IS NULL
    
    FETCH NEXT FROM mycursor INTO @ID, @oldCode, @maxLen, @noUnits, @inchesHigh, @dateReceived, @preferredAisle, @bayNames
           
END 

CLOSE mycursor  
DEALLOCATE mycursor 


Update BayTotals set availFeetInches = dbo.inchesToFeet(availableInches)

--select @newBay as newBay, @sameBay as SameBay, @deltaLen as DeltaLen, @noBay as NOBay


select A.oldCode as code, A.itemMaxLen as maxLen, internalDescription as item, A.dateReceived, A.bayNames, A.bay, A.noUnits, A.inchesUsed, A.comment

from autoBayTransactions A inner join Items I on A.oldCode = I.oldCode
order by A.oldCode, A.itemMaxLen, A.dateReceived
GO
