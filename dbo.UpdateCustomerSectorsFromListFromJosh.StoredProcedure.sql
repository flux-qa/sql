USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateCustomerSectorsFromListFromJosh]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateCustomerSectorsFromListFromJosh]
as
declare a cursor for select oldcustno, cast(sector as integer) from customersWithNoSector
declare @oldcustno char(6)
declare @sector integer

open  a
FETCH NEXT FROM a INTO @oldcustno, @sector 

WHILE @@FETCH_STATUS = 0  
BEGIN 
    update customers set ps_Sector_RID = @sector where oldCustNo = @oldcustno
    
    
    FETCH NEXT FROM a INTO @oldcustno, @sector
end
   CLOSE a 
    DEALLOCATE a
GO
