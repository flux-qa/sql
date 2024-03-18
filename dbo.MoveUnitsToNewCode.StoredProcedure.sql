USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[MoveUnitsToNewCode]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create Procedure [dbo].[MoveUnitsToNewCode]        
        
        @oldcode    char(5),
        @newcode    char(5)
        
as


declare @oldItem integer
declare @newItem integer

select @oldItem = ID from Items where oldCode = @oldCode
select @newItem = ID from Items where oldCode = @newCode

Update Units set ob_Items_RID = @newItem where ob_Items_RID = @oldItem
    and UMStock > 0
GO
