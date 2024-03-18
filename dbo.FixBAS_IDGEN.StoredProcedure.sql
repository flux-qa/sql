USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[FixBAS_IDGEN]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create procedure [dbo].[FixBAS_IDGEN]

as

declare @maxID integer
declare @tempMaxID integer
-- FIND Largest in OrderTally, QuoteUnits, CADTransactions and UnitLengths

select @MaxID = max(ID) from OrderTally

select @maxID

select @tempMaxID = max(ID) from QuoteUnits
if @tempMaxID > @maxID
    set @maxID = @tempMaxID
    
select @maxID, @tempMaxID   
    
select @tempMaxID = max(ID) from CADTransactions
if @tempMaxID > @maxID
    set @maxID = @tempMaxID
    
select @maxID, @tempMaxID 
  
select @tempMaxID = max(ID) from UnitLengths
if @tempMaxID > @maxID
    set @maxID = @tempMaxID
    
select @maxID, @tempMaxID  
 
Update BAS_IDGEN set Max_ID = @MaxID + 1000
GO
