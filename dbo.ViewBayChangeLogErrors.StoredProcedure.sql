USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ViewBayChangeLogErrors]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE procedure [dbo].[ViewBayChangeLogErrors]


as

declare @auditDate  date
set @auditDate = getdate()

select U.unit, U.location as currentBay, B.newBay, U.umStock
    from BayChangeLogAudit B inner join 
    
    (select unitNumber, max(ID) as maxID from BayChangeLogAudit 
    where cast(dateEntered as date) = @auditDate group by unitNumber ) as Z
        on Z.maxID = B.ID
    inner join Units U on B.unitNumber = U.unit
    where  U.location <> B.newBay
GO
