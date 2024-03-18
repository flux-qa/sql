USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[AssignPreferredBayToPO]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[AssignPreferredBayToPO]

-- Last Change 3/5/22 -- test
-- Last Change 12/17/22 -- Updating Unit Location with Preferred Bay 
-- Added Deep Storage Data Retrieval

@PONumber       integer = 43278

AS

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
        @bayNames       varchar(4),
        @east1WestMinus1    integer,
        @eastWestMsg    varchar(10),
        @unit           integer,
        @active         integer,
        @oldArea        varchar(20),
        @stockForLength integer,
        @usage3M        integer
        
-- TEMP VARIABLES
Declare @bay            varchar(6),
        @available      integer,
        @noMonthsDeep   integer = 3
    
    
-- CLEAR THE PREFERRED BAY IN THE UNITS TABLE
Update Units set preferredBay = null, preferredBayReason = ''
from Units U inner join PurchaseLines L on U.ps_PurchaseLines_RID = L.ID
where L.PONumber = @PONumber and U.dateReceived is NULL

Delete from TempBaysForReceiving WHERE PONumber = @PONumber

        
DECLARE myCursor CURSOR FOR   


select 
    I.ID, I.oldCode, count(*) as noUnits,  UL.longLength, M.inchesHigh, bayName,
    max(case when UD.location IS NULL THEN 0 
    when left(UD.location,1) >= '1' and left(UD.location,1) <= '5' then -1 
    when left(UD.location,1) = '0' OR (left(UD.location,1) >= '6' and left(UD.location,1) <= '9') 
		then 1 else 0 end) as East1WestMinus1,
    max(case when UD.location IS NULL THEN '' 
    when left(UD.location,1) >= '1' and left(UD.location,1) <= '5' then ' Want WEST' 
    when left(UD.location,1) = '0' OR (left(UD.location,1) >= '6' and left(UD.location,1) <= '9') 	
		then 'Want EAST' else '' end) as EastWestMsg,
    max(case when ONA.active = 1 then 1 else 0 end) as active, max(ONA.oldArea) as oldArea,
    max(stockForLength), max(usage3M)
    
    
    from Units U inner join Items I on U.ob_Items_RID = I.ID
    inner join PurchaseLines PL on U.ps_PurchaseLines_RID = PL.ID
    inner join (select ob_Units_RID, max(length) as longLength from UnitLengths 
		where qtyInTransit > 0 group by ob_Units_RID) as UL on UL.ob_Units_RID = U.ID
    left outer join  UnitMaxLenData M  on M.ob_Item_RID = U.ob_Items_RID and M.maxLength = UL.longLength
    -- USED TO DETERMINE IF AREA IS ACTIVE
    left outer join oldNewAreas ONA on ONA.newArea = bayName
    -- USED TO GET EAST OR WEST
    left outer join UnDigByMaxLen UD on UD.ob_Items_RID = I.ID and UD.maxlen = UL.longLength
    left outer join (select UML.ob_Item_RID, UML.maxLength,
    stockForLength, case when bayName = 'A-B' then 2 else 1 end * @noMonthsDeep * UML.monthlyUsage as Usage3M,
    case when case when bayName = 'A-B' then 2 else 1 end * @noMonthsDeep * UML.monthlyUsage >= StockForLength 
		OR UML.stdReceivedUnitSize * 2 >= StockForLength then 0  
        else StockForLength - (case when bayName = 'A-B' then 2 else 1 end * @noMonthsDeep * UML.monthlyUsage) end as ToDeep
        ,Z.lastReceived
    from UnitMaxLenData UML

    left outer join -- THIS IS USED TO GET QTY FOR DEEP STORAGE
    (select ob_Items_RID, longlength, sum(UMStock) as StockForLength,  max(dateReceived) as lastReceived 
    from Units where UMStock > 0 and unitType = 'I' and lostFlag = 0
    group by ob_Items_RID, longlength ) as Z on Z.ob_Items_RID = UML.ob_Item_RID and Z.longLength = UML.maxLength) 
        as w on W.ob_Item_RID = I.ID and W.maxLength = M.maxLength
    
    where PL.PONumber = @PONumber and U.dateReceived IS NULL

    group by I.ID, oldCode, UL.longLength, M.inchesHigh, cast(U.dateEntered as date), bayname
    order by I.oldCode, UL.longLength

   

OPEN myCursor 
FETCH NEXT FROM mycursor INTO  @ID, @oldCode, @noUnits, @maxLen, @inchesHigh,  @bayNames, @east1WestMinus1, @eastWestMsg,
    @active, @oldArea, @stockForLength, @usage3M
WHILE @@FETCH_STATUS = 0  
BEGIN 
    set @bay = null


-- SEE IF SHOULD BE IN DEEP STORAGE
/*
IF @stockForLength > @usage3M BEGIN

   -- SEE IF THERE IS A BAY WHERE THIS ITEM ALREADY IS
    IF @bay IS NULL BEGIN 
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B INNER JOIN Units A on B.bay = A.location
        left outer join (select bay, sum(inches) as tempInches from TempBaysForReceiving group by bay)
            as TB on B.bay = TB.bay
        inner join PurchaseLines PL on A.ps_PurchaseLines_RID = PL.ID
        where B.maxLen = @maxLen AND
            A.ob_Items_RID = @ID AND
            PL.PONumber = @PONumber AND
            B.availableInches - isNull(TB.tempInches,0) >= ROUND(@noUnits * @inchesHigh,0)
            and B.deepStorage = 1
        order by B.eastFactor * @east1WestMinus1 desc, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
            -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO SAME BAY
            Update Units set preferredBay = @bay, preferredBayReason = 
				cast(@maxLen as varchar(2)) + ''''  + ' Existing Deep Bay ' + cast(@noUnits as varchar(3)) + ' Unit(s)'
            from Units U inner join PurchaseLines L on U.ps_purchaseLines_RID = L.ID
            inner join (select ob_Units_RID, max(length) as longLength from UnitLengths where qtyInTransit > 0 group by ob_Units_RID)
            as UL on UL.ob_Units_RID = U.ID
            inner join UnitMaxLenData UML on UML.ob_Item_RID = U.ob_Items_RID and UML.maxLength = UL.longLength
            where L.PONumber = @PONumber and L.ob_Items_RID = @ID and UL.longLength = @maxLen and U.preferredBay is not null

            
            -- INSERT INTO TempBaysForReceiving - Used to allocate space for rolling
            insert into TempBaysForReceiving (ID, BASVERSION, BASTIMESTAMP, PONumber, LineNumber, unit, inches, bay)
            select NEXT VALUE FOR MYSEQ, 1, getdate(),
            @PONumber, L.lineNumber, U.unit, UML.inchesHigh, U.preferredBay

            from Units U inner join PurchaseLines L on U.ps_PurchaseLines_RID = L.ID
            inner join (select ob_Units_RID, max(length) as longLength from UnitLengths where qtyInTransit > 0 group by ob_Units_RID)
            as UL on UL.ob_Units_RID = U.ID
            inner join UnitMaxLenData UML on UML.ob_Item_RID = U.ob_Items_RID and UML.maxLength = UL.longLength        
            where L.PONumber = @PONumber and L.ob_Items_RID = @ID and UL.longLength = @maxLen and U.preferredBay is not null
            
            END -- END OF IF SAME BAY
        END -- IF BAY IS NULL
    
    IF @bay IS NULL BEGIN 
        -- SEE IF THERE IS A NEW BAY FOR THIS QTY
        select top 1 @bay = B.bay, @available = B.availableInches
        from BayTotals B 
        left outer join (select bay, sum(inches) as tempInches from TempBaysForReceiving group by bay)
            as TB on B.bay = TB.bay
        where B.maxLen = @maxLen AND
             B.availableInches - isNull(TB.tempInches,0) >= ROUND(@noUnits * @inchesHigh,0) and  
            (left(B.bay,1) = Left(@baynames,1) or left(B.bay,1) = right(@baynames,1)) AND
            --@preferredAisle = B.aisle AND
            B.deepStorage = 1 
        order by --(B.eastFactor * @east1WestMinus1) 
        case when (B.eastFactor = 1 and @east1WestMinus1 = 1) OR B.eastFactor = -1 and @east1WestMinus1 = -1 then 1 
			when @east1WestMinus1 = 0 then 2 else 3 end, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
            -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            Update Units set preferredBay = @bay, preferredBayReason = 
				cast(@maxLen as varchar(2)) + '''' + 'New Deep Bay ' + cast(@noUnits as varchar(3)) + ' Unit(s) ' + @eastWestMsg
            from Units U inner join PurchaseLines L on U.ps_purchaseLines_RID = L.ID
            inner join (select ob_Units_RID, max(length) as longLength from UnitLengths where qtyInTransit > 0 group by ob_Units_RID)
                as UL on UL.ob_Units_RID = U.ID    
            inner join UnitMaxLenData UML on UML.ob_Item_RID = U.ob_Items_RID and UML.maxLength = UL.longLength
            where L.PONumber = @PONumber and L.ob_Items_RID = @ID and UL.longLength = @maxLen and U.preferredBay is not null            


            -- INSERT INTO TempBaysForReceiving - Used to allocate space for rolling
            insert into TempBaysForReceiving (ID, BASVERSION, BASTIMESTAMP, PONumber, LineNumber, unit, inches, bay)
            select NEXT VALUE FOR MYSEQ, 1, getdate(),
            @PONumber, L.lineNumber, U.unit, UML.inchesHigh, U.preferredBay

            from Units U inner join PurchaseLines L on U.ps_PurchaseLines_RID = L.ID
            inner join (select ob_Units_RID, max(length) as longLength from UnitLengths where qtyInTransit > 0 group by ob_Units_RID)
            as UL on UL.ob_Units_RID = U.ID
            inner join UnitMaxLenData UML on UML.ob_Item_RID = U.ob_Items_RID and UML.maxLength = UL.longLength        
            where L.PONumber = @PONumber and L.ob_Items_RID = @ID and UL.longLength = @maxLen and U.preferredBay is not null                     
            END -- END NEW BAY
        END -- END IF BAY IS NULL

IF @bay IS NULL BEGIN
        -- SEE IF THERE IS A BAY + 2"
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B 
        left outer join (select bay, sum(inches) as tempInches from TempBaysForReceiving group by bay)
            as TB on B.bay = TB.bay
        where B.maxLen - @maxLen <= 2 AND
             B.availableInches - isNull(TB.tempInches,0) >= ROUND(@noUnits * @inchesHigh,0) AND
            B.deepStorage <> 1
            and (left(B.bay,1) = LEFT(@baynames,1) OR left(B.bay,1) = RIGHT(@bayNames,1))
        order by --(B.eastFactor * @east1WestMinus1) 
        case when (B.eastFactor = 1 and @east1WestMinus1 = 1) OR B.eastFactor = -1 and @east1WestMinus1 = -1 then 1 
			when @east1WestMinus1 = 0 then 2 else 3 end, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
            -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            Update Units set preferredBay = @bay, preferredBayReason = 
				cast(@maxLen as varchar(2)) + ''''  + 'Delta Max Len Deep '  + cast(@noUnits as varchar(3)) + ' Unit(s) ' + @eastWestMsg
            from Units U inner join PurchaseLines L on U.ps_purchaseLines_RID = L.ID
            inner join (select ob_Units_RID, max(length) as longLength from UnitLengths where qtyInTransit > 0 group by ob_Units_RID)
                as UL on UL.ob_Units_RID = U.ID
            inner join UnitMaxLenData UML on UML.ob_Item_RID = U.ob_Items_RID and UML.maxLength = UL.longLength
            where L.PONumber = @PONumber and L.ob_Items_RID = @ID and UL.longLength = @maxLen and U.preferredBay is not null

            -- INSERT INTO TempBaysForReceiving - Used to allocate space for rolling
            insert into TempBaysForReceiving (ID, BASVERSION, BASTIMESTAMP, PONumber, LineNumber, unit, inches, bay)
            select NEXT VALUE FOR MYSEQ, 1, getdate(),
            @PONumber, L.lineNumber, U.unit, UML.inchesHigh, U.preferredBay

            from Units U inner join PurchaseLines L on U.ps_PurchaseLines_RID = L.ID
            inner join (select ob_Units_RID, max(length) as longLength from UnitLengths where qtyInTransit > 0 group by ob_Units_RID)
            as UL on UL.ob_Units_RID = U.ID
            inner join UnitMaxLenData UML on UML.ob_Item_RID = U.ob_Items_RID and UML.maxLength = UL.longLength        
            where L.PONumber = @PONumber and L.ob_Items_RID = @ID and UL.longLength = @maxLen and U.preferredBay is null        
            END -- END +/- 2"
        END -- IF BAY IS NULL

END -- DEEP BAY LOGIC -- IF @Stock > @MonthlyUsage

*/





    --print @oldCode + '  ' + cast(@noUnits as varchar(3)) + '  len: ' +  cast(@maxLen as varchar(2))
      
    -- SEE IF THERE IS A BAY WHERE THIS ITEM ALREADY IS
    IF @bay IS NULL BEGIN 
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B INNER JOIN Units A on B.bay = A.location
        left outer join (select bay, sum(inches) as tempInches from TempBaysForReceiving group by bay)
            as TB on B.bay = TB.bay
        inner join PurchaseLines PL on A.ps_PurchaseLines_RID = PL.ID
        where B.maxLen = @maxLen AND
            A.ob_Items_RID = @ID AND
            PL.PONumber = @PONumber AND
            B.availableInches - isNull(TB.tempInches,0) >= ROUND(@noUnits * @inchesHigh,0)
            and B.deepStorage = 0
        order by B.eastFactor * @east1WestMinus1 desc, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
            -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO SAME BAY
            Update Units set preferredBay = @bay, preferredBayReason = 
				cast(@maxLen as varchar(2)) + ''''  + ' Existing Bay ' + cast(@noUnits as varchar(3)) + ' Unit(s)'
            from Units U inner join PurchaseLines L on U.ps_purchaseLines_RID = L.ID
            inner join (select ob_Units_RID, max(length) as longLength from UnitLengths where qtyInTransit > 0 group by ob_Units_RID)
            as UL on UL.ob_Units_RID = U.ID
            inner join UnitMaxLenData UML on UML.ob_Item_RID = U.ob_Items_RID and UML.maxLength = UL.longLength
            where L.PONumber = @PONumber and L.ob_Items_RID = @ID and UL.longLength = @maxLen and U.preferredBay is not null

            
            -- INSERT INTO TempBaysForReceiving - Used to allocate space for rolling
            insert into TempBaysForReceiving (ID, BASVERSION, BASTIMESTAMP, PONumber, LineNumber, unit, inches, bay)
            select NEXT VALUE FOR MYSEQ, 1, getdate(),
            @PONumber, L.lineNumber, U.unit, UML.inchesHigh, U.preferredBay

            from Units U inner join PurchaseLines L on U.ps_PurchaseLines_RID = L.ID
            inner join (select ob_Units_RID, max(length) as longLength from UnitLengths where qtyInTransit > 0 group by ob_Units_RID)
            as UL on UL.ob_Units_RID = U.ID
            inner join UnitMaxLenData UML on UML.ob_Item_RID = U.ob_Items_RID and UML.maxLength = UL.longLength        
            where L.PONumber = @PONumber and L.ob_Items_RID = @ID and UL.longLength = @maxLen and U.preferredBay is not null
            
            END -- END OF IF SAME BAY
        END -- IF BAY IS NULL
    
    IF @bay IS NULL BEGIN 
        -- SEE IF THERE IS A NEW BAY FOR THIS QTY
        select top 1 @bay = B.bay, @available = B.availableInches
        from BayTotals B 
        left outer join (select bay, sum(inches) as tempInches from TempBaysForReceiving group by bay)
            as TB on B.bay = TB.bay
        where B.maxLen = @maxLen AND
             B.availableInches - isNull(TB.tempInches,0) >= ROUND(@noUnits * @inchesHigh,0) and  
            (left(B.bay,1) = Left(@baynames,1) or left(B.bay,1) = right(@baynames,1)) AND
            --@preferredAisle = B.aisle AND
            B.deepStorage <> 1 
        order by --(B.eastFactor * @east1WestMinus1) 
        case when (B.eastFactor = 1 and @east1WestMinus1 = 1) OR B.eastFactor = -1 and @east1WestMinus1 = -1 then 1 
			when @east1WestMinus1 = 0 then 2 else 3 end, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
            -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            Update Units set preferredBay = @bay, preferredBayReason = 
				cast(@maxLen as varchar(2)) + '''' + 'New Bay ' + cast(@noUnits as varchar(3)) + ' Unit(s) ' + @eastWestMsg
            from Units U inner join PurchaseLines L on U.ps_purchaseLines_RID = L.ID
            inner join (select ob_Units_RID, max(length) as longLength from UnitLengths where qtyInTransit > 0 group by ob_Units_RID)
                as UL on UL.ob_Units_RID = U.ID    
            inner join UnitMaxLenData UML on UML.ob_Item_RID = U.ob_Items_RID and UML.maxLength = UL.longLength
            where L.PONumber = @PONumber and L.ob_Items_RID = @ID and UL.longLength = @maxLen and U.preferredBay is not null            


            -- INSERT INTO TempBaysForReceiving - Used to allocate space for rolling
            insert into TempBaysForReceiving (ID, BASVERSION, BASTIMESTAMP, PONumber, LineNumber, unit, inches, bay)
            select NEXT VALUE FOR MYSEQ, 1, getdate(),
            @PONumber, L.lineNumber, U.unit, UML.inchesHigh, U.preferredBay

            from Units U inner join PurchaseLines L on U.ps_PurchaseLines_RID = L.ID
            inner join (select ob_Units_RID, max(length) as longLength from UnitLengths where qtyInTransit > 0 group by ob_Units_RID)
            as UL on UL.ob_Units_RID = U.ID
            inner join UnitMaxLenData UML on UML.ob_Item_RID = U.ob_Items_RID and UML.maxLength = UL.longLength        
            where L.PONumber = @PONumber and L.ob_Items_RID = @ID and UL.longLength = @maxLen and U.preferredBay is not null           
            
            END -- END NEW BAY
        END -- END IF @bay IS NULL
      
      
    IF @bay IS NULL BEGIN
        -- SEE IF THERE IS A BAY + 2"
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B 
        left outer join (select bay, sum(inches) as tempInches from TempBaysForReceiving group by bay)
            as TB on B.bay = TB.bay
        where B.maxLen - @maxLen <= 2 AND
             B.availableInches - isNull(TB.tempInches,0) >= ROUND(@noUnits * @inchesHigh,0) AND
            B.deepStorage <> 1
            and (left(B.bay,1) = LEFT(@baynames,1) OR left(B.bay,1) = RIGHT(@bayNames,1))
        order by --(B.eastFactor * @east1WestMinus1) 
        case when (B.eastFactor = 1 and @east1WestMinus1 = 1) OR B.eastFactor = -1 and @east1WestMinus1 = -1 then 1 
			when @east1WestMinus1 = 0 then 2 else 3 end, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
            -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            Update Units set preferredBay = @bay, preferredBayReason = 
				cast(@maxLen as varchar(2)) + ''''  + 'Delta Max Len '  + cast(@noUnits as varchar(3)) + ' Unit(s) ' + @eastWestMsg
            from Units U inner join PurchaseLines L on U.ps_purchaseLines_RID = L.ID
            inner join (select ob_Units_RID, max(length) as longLength from UnitLengths where qtyInTransit > 0 group by ob_Units_RID)
                as UL on UL.ob_Units_RID = U.ID
            inner join UnitMaxLenData UML on UML.ob_Item_RID = U.ob_Items_RID and UML.maxLength = UL.longLength
            where L.PONumber = @PONumber and L.ob_Items_RID = @ID and UL.longLength = @maxLen and U.preferredBay is not null

            -- INSERT INTO TempBaysForReceiving - Used to allocate space for rolling
            insert into TempBaysForReceiving (ID, BASVERSION, BASTIMESTAMP, PONumber, LineNumber, unit, inches, bay)
            select NEXT VALUE FOR MYSEQ, 1, getdate(),
            @PONumber, L.lineNumber, U.unit, UML.inchesHigh, U.preferredBay

            from Units U inner join PurchaseLines L on U.ps_PurchaseLines_RID = L.ID
            inner join (select ob_Units_RID, max(length) as longLength from UnitLengths where qtyInTransit > 0 group by ob_Units_RID)
            as UL on UL.ob_Units_RID = U.ID
            inner join UnitMaxLenData UML on UML.ob_Item_RID = U.ob_Items_RID and UML.maxLength = UL.longLength        
            where L.PONumber = @PONumber and L.ob_Items_RID = @ID and UL.longLength = @maxLen and U.preferredBay is null

            
            END -- END NEW BAY
        END -- END IF @bay IS NULL          
      

    IF @bay IS NULL BEGIN
        -- SEE IF THERE IS A ALTERNATE BAY
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B 
        left outer join (select bay, sum(inches) as tempInches from TempBaysForReceiving group by bay)
            as TB on B.bay = TB.bay
        where ABS(B.maxLen - @maxLen) <= 2 AND
             B.availableInches - isNull(TB.tempInches,0) >= ROUND(@noUnits * @inchesHigh,0) AND
            B.deepStorage <> 1
            AND ((left(@baynames,1) = '3' AND left(b.bay,1) = '4')
                OR (left(@baynames,1) = '4' AND left(b.bay,1) = '3')
                OR (CHARINDEX(left(@baynames,1), 'E, F, G, H, I, J, K, L') > 0 AND
                CHARINDEX(left(B.bay,1), 'E, F, G, H, I, J, K, L') > 0))
        order by --(B.eastFactor * @east1WestMinus1) 
        case when (B.eastFactor = 1 and @east1WestMinus1 = 1) OR B.eastFactor = -1 and @east1WestMinus1 = -1 then 1 
			when @east1WestMinus1 = 0 then 2 else 3 end, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
            -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            Update Units set preferredBay = @bay, preferredBayReason = 
				cast(@maxLen as varchar(2)) + ''''  + ' Alt ' + cast(@noUnits as varchar(3)) + ' Unit(s) ' + @eastWestMsg
            from Units U inner join PurchaseLines L on U.ps_purchaseLines_RID = L.ID
            where U.ob_Items_RID = @ID AND L.PONumber = @PONumber and U.preferredBay is null
            
            -- INSERT INTO TempBaysForReceiving - Used to allocate space for rolling
            insert into TempBaysForReceiving (ID, BASVERSION, BASTIMESTAMP, PONumber, LineNumber, unit, inches, bay)
            select NEXT VALUE FOR MYSEQ, 1, getdate(),
            @PONumber, L.lineNumber, U.unit, UML.inchesHigh, U.preferredBay

            from Units U inner join PurchaseLines L on U.ps_PurchaseLines_RID = L.ID
            inner join (select ob_Units_RID, max(length) as longLength from UnitLengths where qtyInTransit > 0 group by ob_Units_RID)
            as UL on UL.ob_Units_RID = U.ID
            inner join UnitMaxLenData UML on UML.ob_Item_RID = U.ob_Items_RID and UML.maxLength = UL.longLength        
            where L.PONumber = @PONumber and L.ob_Items_RID = @ID and UL.longLength = @maxLen and U.preferredBay is not null

            
            END -- END NEW BAY
        END -- END IF @bay IS NULL          
      
 /*    
    IF @bay IS NULL BEGIN
            Update Units set preferredBay = 'NONE'
            from Units U inner join PurchaseLines L on U.ps_purchaseLines_RID = L.ID
            where U.ob_Items_RID = @ID AND L.PONumber = @PONumber and U.preferredBay is null
        END -- END IF @bay IS NULL
*/    
FETCH NEXT FROM mycursor INTO  @ID, @oldCode, @noUnits, @maxLen, @inchesHigh,  @bayNames, @east1WestMinus1, @eastWestMsg,
    @active, @oldArea, @stockForLength, @usage3M
END 

CLOSE mycursor  
DEALLOCATE mycursor 

/*
* -- NOW DO THE SINGLE UNITS THAT ARE LEFT
*/

DECLARE myCursor CURSOR FOR   


select 
    I.ID, I.oldCode, 1 as noUnits,  UL.longLength, M.inchesHigh, bayName,
    case when UD.location IS NULL THEN 0 
    when left(UD.location,1) >= '1' and left(UD.location,1) <= '5' then -1 
    when left(UD.location,1) = '0' OR (left(UD.location,1) >= '6' and left(UD.location,1) <= '9') 
		then 1 else 0 end as East1WestMinus1,
    case when UD.location IS NULL THEN '' 
    when left(UD.location,1) >= '1' and left(UD.location,1) <= '5' then ' Want WEST' 
    when left(UD.location,1) = '0' OR (left(UD.location,1) >= '6' and left(UD.location,1) <= '9') 
		then 'Want EAST' else '' end as EastWestMsg, 
    U.unit, ONA.active, ONA.oldArea, stockForLength, usage3M
    
    
    from Units U inner join Items I on U.ob_Items_RID = I.ID
    inner join PurchaseLines PL on U.ps_PurchaseLines_RID = PL.ID
    inner join (select ob_Units_RID, max(length) as longLength from UnitLengths where qtyInTransit > 0 group by ob_Units_RID)
        as UL on UL.ob_Units_RID = U.ID
    left outer join  UnitMaxLenData M  on M.ob_Item_RID = U.ob_Items_RID and M.maxLength = UL.longLength
    -- USED TO DETERMINE IF AREA IS ACTIVE
    left outer join oldNewAreas ONA on ONA.newArea = bayName
    -- USED TO GET EAST OR WEST
    left outer join UnDigByMaxLen UD on UD.ob_Items_RID = I.ID and UD.maxlen = UL.longLength
    left outer join (select UML.ob_Item_RID, UML.maxLength,
    stockForLength, case when bayName = 'A-B' then 2 else 1 end * @noMonthsDeep * UML.monthlyUsage as Usage3M,
    case when case when bayName = 'A-B' then 2 else 1 end * @noMonthsDeep * UML.monthlyUsage >= StockForLength 
		OR UML.stdReceivedUnitSize * 2 >= StockForLength then 0  
        else StockForLength - (case when bayName = 'A-B' then 2 else 1 end * @noMonthsDeep * UML.monthlyUsage) end as ToDeep
        ,Z.lastReceived
    from UnitMaxLenData UML
 
    left outer join -- THIS IS USED TO GET QTY FOR DEEP STORAGE
    (select ob_Items_RID, longlength, sum(UMStock) as StockForLength,  max(dateReceived) as lastReceived 
    from Units where UMStock > 0 and unitType = 'I' and lostFlag = 0
    group by ob_Items_RID, longlength ) as Z on Z.ob_Items_RID = UML.ob_Item_RID and Z.longLength = UML.maxLength) 
        as w on W.ob_Item_RID = I.ID and W.maxLength = M.maxLength
    
    where PL.PONumber = @PONumber AND U.preferredBay IS NULL

    order by I.oldCode, UL.longLength

   

OPEN myCursor 
FETCH NEXT FROM mycursor INTO  @ID, @oldCode, @noUnits, @maxLen, @inchesHigh,  @bayNames, @east1WestMinus1, @eastWestMsg,
    @unit, @active, @oldArea, @stockForLength, @usage3M
    
WHILE @@FETCH_STATUS = 0  
    
BEGIN 
    set @bay = null
    


-- SEE IF SHOULD BE IN DEEP STORAGE
/*
IF @stockForLength > @usage3M BEGIN


    -- SEE IF THERE IS A BAY WHERE THIS ITEM ALREADY IS
    IF @bay IS NULL BEGIN 
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B INNER JOIN Units A on B.bay = A.location
        left outer join (select bay, sum(inches) as tempInches from TempBaysForReceiving group by bay)
            as TB on B.bay = TB.bay
        inner join PurchaseLines PL on A.ps_PurchaseLines_RID = PL.ID
        where B.maxLen = @maxLen AND
            A.ob_Items_RID = @ID AND
            PL.PONumber = @PONumber AND
             B.availableInches - isNull(TB.tempInches,0) >= ROUND(@noUnits * @inchesHigh,0)
            and B.deepStorage = 1
        order by B.eastFactor * @east1WestMinus1 desc, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
            -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO SAME BAY
            Update Units set preferredBay = @bay, preferredBayReason = cast(@maxLen as varchar(2)) + ''''  + 'Existing Deep Bay'
            where unit = @unit
            
            -- INSERT INTO TempBaysForReceiving - Used to allocate space for rolling
            insert into TempBaysForReceiving (ID, BASVERSION, BASTIMESTAMP, PONumber, LineNumber, unit, inches, bay)
            select NEXT VALUE FOR MYSEQ, 1, getdate(),
            @PONumber, 0, @unit, @inchesHigh, @bay

            
            END -- END OF IF SAME BAY
        END -- IF BAY IS NULL
				
				
    IF @bay IS NULL BEGIN 
        -- SEE IF THERE IS A NEW BAY FOR THIS QTY
        select top 1 @bay = B.bay, @available = B.availableInches
        from BayTotals B 
        left outer join (select bay, sum(inches) as tempInches from TempBaysForReceiving group by bay)
            as TB on B.bay = TB.bay
        where B.maxLen = @maxLen AND
             B.availableInches - isNull(TB.tempInches,0) >= ROUND(@noUnits * @inchesHigh,0) and  
            (left(B.bay,1) = Left(@baynames,1) or left(B.bay,1) = right(@baynames,1)) AND
            --@preferredAisle = B.aisle AND
            B.deepStorage <> 1 
        order by --(B.eastFactor * @east1WestMinus1) 
        case when (B.eastFactor = 1 and @east1WestMinus1 = 1) OR B.eastFactor = -1 and @east1WestMinus1 = -1 then 1 
			when @east1WestMinus1 = 0 then 2 else 3 end, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
            -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            Update Units set preferredBay = @bay, preferredBayReason = cast(@maxLen as varchar(2)) + ''''  + ' New Deep Bay ' + @eastWestMsg
            where unit = @unit

            -- INSERT INTO TempBaysForReceiving - Used to allocate space for rolling
            insert into TempBaysForReceiving (ID, BASVERSION, BASTIMESTAMP, PONumber, LineNumber, unit, inches, bay)
            select NEXT VALUE FOR MYSEQ, 1, getdate(),
            @PONumber, 0, @unit, @inchesHigh, @bay

            
            END -- END NEW BAY
        END -- END IF @bay IS NULL
  				
      
    IF @bay IS NULL BEGIN
        -- SEE IF THERE IS A BAY + 2"
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B 
        left outer join (select bay, sum(inches) as tempInches from TempBaysForReceiving group by bay)
            as TB on B.bay = TB.bay
        where B.maxLen - @maxLen <= 2 AND
             B.availableInches - isNull(TB.tempInches,0) >= ROUND(@noUnits * @inchesHigh,0) AND
            B.deepStorage <> 1
            and (left(B.bay,1) = LEFT(@baynames,1) OR left(B.bay,1) = RIGHT(@bayNames,1))
        order by --(B.eastFactor * @east1WestMinus1) 
        case when (B.eastFactor = 1 and @east1WestMinus1 = 1) OR B.eastFactor = -1 and @east1WestMinus1 = -1 then 1 
			when @east1WestMinus1 = 0 then 2 else 3 end, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
            -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            Update Units set preferredBay = @bay, preferredBayReason = cast(@maxLen as varchar(2)) + ''''  + ' Delta Len Deep ' + @eastWestMsg
            where unit = @unit

            -- INSERT INTO TempBaysForReceiving - Used to allocate space for rolling
            insert into TempBaysForReceiving (ID, BASVERSION, BASTIMESTAMP, PONumber, LineNumber, unit, inches, bay)
            select NEXT VALUE FOR MYSEQ, 1, getdate(),
            @PONumber, 0, @unit, @inchesHigh, @bay

            END -- END NEW BAY +/- 2"
        END -- END IF @bay IS NULL      					

END -- END Deep Storage Logic. If @StockForLength > @usage3M
*/

 
    -- SEE IF THERE IS A BAY WHERE THIS ITEM ALREADY IS
    IF @bay IS NULL BEGIN 
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B INNER JOIN Units A on B.bay = A.location
        left outer join (select bay, sum(inches) as tempInches from TempBaysForReceiving group by bay)
            as TB on B.bay = TB.bay
        inner join PurchaseLines PL on A.ps_PurchaseLines_RID = PL.ID
        where B.maxLen = @maxLen AND
            A.ob_Items_RID = @ID AND
            PL.PONumber = @PONumber AND
             B.availableInches - isNull(TB.tempInches,0) >= ROUND(@noUnits * @inchesHigh,0)
            and B.deepStorage = 0
        order by B.eastFactor * @east1WestMinus1 desc, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
            -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO SAME BAY
            Update Units set preferredBay = @bay, preferredBayReason = cast(@maxLen as varchar(2)) + ''''  + 'Existing Bay'
            where unit = @unit
            
            -- INSERT INTO TempBaysForReceiving - Used to allocate space for rolling
            insert into TempBaysForReceiving (ID, BASVERSION, BASTIMESTAMP, PONumber, LineNumber, unit, inches, bay)
            select NEXT VALUE FOR MYSEQ, 1, getdate(),
            @PONumber, 0, @unit, @inchesHigh, @bay

            
            END -- END OF IF SAME BAY
        END -- IF BAY IS NULL
    
    IF @bay IS NULL BEGIN 
        -- SEE IF THERE IS A NEW BAY FOR THIS QTY
        select top 1 @bay = B.bay, @available = B.availableInches
        from BayTotals B 
        left outer join (select bay, sum(inches) as tempInches from TempBaysForReceiving group by bay)
            as TB on B.bay = TB.bay
        where B.maxLen = @maxLen AND
             B.availableInches - isNull(TB.tempInches,0) >= ROUND(@noUnits * @inchesHigh,0) and  
            (left(B.bay,1) = Left(@baynames,1) or left(B.bay,1) = right(@baynames,1)) AND
            --@preferredAisle = B.aisle AND
            B.deepStorage <> 1 
        order by --(B.eastFactor * @east1WestMinus1) 
        case when (B.eastFactor = 1 and @east1WestMinus1 = 1) OR B.eastFactor = -1 and @east1WestMinus1 = -1 then 1 
			when @east1WestMinus1 = 0 then 2 else 3 end, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
            -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            Update Units set preferredBay = @bay, preferredBayReason = cast(@maxLen as varchar(2)) + ''''  + ' New Bay ' + @eastWestMsg
            where unit = @unit

            -- INSERT INTO TempBaysForReceiving - Used to allocate space for rolling
            insert into TempBaysForReceiving (ID, BASVERSION, BASTIMESTAMP, PONumber, LineNumber, unit, inches, bay)
            select NEXT VALUE FOR MYSEQ, 1, getdate(),
            @PONumber, 0, @unit, @inchesHigh, @bay

            
            END -- END NEW BAY
        END -- END IF @bay IS NULL
      
      
    IF @bay IS NULL BEGIN
        -- SEE IF THERE IS A BAY + 2"
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B 
        left outer join (select bay, sum(inches) as tempInches from TempBaysForReceiving group by bay)
            as TB on B.bay = TB.bay
        where B.maxLen - @maxLen <= 2 AND
             B.availableInches - isNull(TB.tempInches,0) >= ROUND(@noUnits * @inchesHigh,0) AND
            B.deepStorage <> 1
            and (left(B.bay,1) = LEFT(@baynames,1) OR left(B.bay,1) = RIGHT(@bayNames,1))
        order by --(B.eastFactor * @east1WestMinus1) 
        case when (B.eastFactor = 1 and @east1WestMinus1 = 1) OR B.eastFactor = -1 and @east1WestMinus1 = -1 then 1 
			when @east1WestMinus1 = 0 then 2 else 3 end, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
            -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            Update Units set preferredBay = @bay, preferredBayReason = cast(@maxLen as varchar(2)) + ''''  + ' Delta Len ' + @eastWestMsg
            where unit = @unit

            -- INSERT INTO TempBaysForReceiving - Used to allocate space for rolling
            insert into TempBaysForReceiving (ID, BASVERSION, BASTIMESTAMP, PONumber, LineNumber, unit, inches, bay)
            select NEXT VALUE FOR MYSEQ, 1, getdate(),
            @PONumber, 0, @unit, @inchesHigh, @bay

            END -- END NEW BAY +/- 2"
        END -- END IF @bay IS NULL          
      

    IF @bay IS NULL BEGIN
        -- SEE IF THERE IS A ALTERNATE BAY
        select top 1 @bay = B.bay, @available = B.availableInches 
        from BayTotals B 
        left outer join (select bay, sum(inches) as tempInches from TempBaysForReceiving group by bay)
            as TB on B.bay = TB.bay
        where ABS(B.maxLen - @maxLen) <= 2 AND
             B.availableInches - isNull(TB.tempInches,0) >= ROUND(@noUnits * @inchesHigh,0) AND
            B.deepStorage <> 1
            AND ((left(@baynames,1) = '3' AND left(b.bay,1) = '4')
                OR (left(@baynames,1) = '4' AND left(b.bay,1) = '3')
                OR (CHARINDEX(left(@baynames,1), 'E, F, G, H, I, J, K, L') > 0 AND
                CHARINDEX(left(B.bay,1), 'E, F, G, H, I, J, K, L') > 0))
        order by --(B.eastFactor * @east1WestMinus1) 
        case when (B.eastFactor = 1 and @east1WestMinus1 = 1) OR B.eastFactor = -1 and @east1WestMinus1 = -1 then 1 
			when @east1WestMinus1 = 0 then 2 else 3 end, B.availableInches  desc, B.noUnits
        
        IF @bay IS NOT NULL BEGIN
            -- LOG THE FACT WE ARE PUTTING ALL OF ITEM / MAXLEN INTO 1 BAY
            Update Units set preferredBay = @bay, preferredBayReason = 'Alt ' + @eastWestMsg
            where unit = @unit
            
            -- INSERT INTO TempBaysForReceiving - Used to allocate space for rolling
            insert into TempBaysForReceiving (ID, BASVERSION, BASTIMESTAMP, PONumber, LineNumber, unit, inches, bay)
            select NEXT VALUE FOR MYSEQ, 1, getdate(),
            @PONumber, 0, @unit, @inchesHigh, @bay

            
            END -- END NEW BAY
        END -- END IF @bay IS NULL          
      
    
    IF @bay IS NULL BEGIN
            Update Units set preferredBay = 'NONE'
            where unit = @unit
    END -- END IF @bay IS NULL
    
FETCH NEXT FROM mycursor INTO  @ID, @oldCode, @noUnits, @maxLen, @inchesHigh,  @bayNames, @east1WestMinus1, @eastWestMsg,
    @unit, @active, @oldArea, @stockForLength, @usage3M
               
END 

CLOSE mycursor  
DEALLOCATE mycursor 


Update BayTotals set availFeetInches = dbo.inchesToFeet(availableInches)

-- 12/16/2022 -- update the location with the preferredBay
Update Units set location = left(preferredBay,4)
from Units U inner join PurchaseLines PL on U.ps_PurchaseLines_RID = PL.ID 
inner join PurchaseOrders P on PL.ob_PurchaseOrders_RID = P.ID 
where P.PONumber = @PONumber AND PL.dateReceived IS NULL
GO
