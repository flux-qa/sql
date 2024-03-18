USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[GenerateNewHandlingInstructions]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GenerateNewHandlingInstructions]
    @designDate     date = '02/13/2023',
    @drillNumber    int = 1
as

set nocount on

        
delete from NewHandleOrders where designDate = @designDate and drillNumber = @drillNumber  

exec GenerateNewHandlingInstructionsWestOrEast @designDate, @drillNumber, 0 -- Generate for East
exec GenerateNewHandlingInstructionsWestOrEast @designDate, @drillNumber, 4 -- Generate for West


-- Added 2/14/24
exec CreateHandleTargetMobile @designDate, @drillNumber
exec CreateHandleTargetSources @designDate, @drillNumber
exec CreateHandleTargetLengths @designDate, @drillNumber

-- GET RID OF DUPLICATES CAUSED WHEN SOME SOURCES ARE IN EAST AND SOME ARE IN WHOLE UNIT LOCATIONS
/* -- removed 02/27/23
delete from N
from NewHandleOrders N inner join NewHandleOrders N1 
    on N.ps_OrderLines_RID = N1.ps_OrderLines_RID and N.ID > N1.ID
	
*/
GO
