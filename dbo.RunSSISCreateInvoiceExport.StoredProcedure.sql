USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[RunSSISCreateInvoiceExport]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[RunSSISCreateInvoiceExport]

as
begin
 declare @execution_id bigint
 exec ssisdb.catalog.create_execution 
  @folder_name = 'Accounting'
 ,@project_name = 'CreateInvoiceImportFile'
 ,@package_name = 'CreateInvoiceASCIIFile.dtsx'
 ,@execution_id = @execution_id output

 exec ssisdb.catalog.start_execution @execution_id

end
GO
