USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[SendEmailBayChangeLogErrors]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[SendEmailBayChangeLogErrors]

as


declare @sub varchar(60)
set @sub = 'Bay Change Log Errors for ' + CONVERT(varchar(20), getdate(), 107)

exec msdb.dbo.sp_send_dbmail
@profile_name = 'SQLMail Profile1',
@recipients = 'bruce@bruceL.com',
@subject = @sub,
@query = 'Select * from Lumber.dbo.BayChangeLogErrors',
@execute_query_database = 'Lumber',
--@attach_query_result_as_file = 1, 
--@query_attachment_filename = 'BayChangeErrors.csv',
@query_result_header = 1, 
@query_no_truncate = 0;
GO
