USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateUnitAudit]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateUnitAudit] 

@unit varchar(10) 
as

delete from UnitAudit 

set @unit = '%' + trim(@unit) + '%'

insert into UnitAudit (ID, BASVERSION, BASTIMESTAMP, actionDate, userName, action, description)

select NEXT VALUE FOR mySEQ, 1, getdate(), actionDate, userName, action, description
from (select top 100 A.dateEntered as actionDate, fullName  as userName, A.action, A.description 
	from auditLog A inner join RegularUser R on A.ps_RegularUser_RID = R.ID 
	where description like @unit) as Z
GO
