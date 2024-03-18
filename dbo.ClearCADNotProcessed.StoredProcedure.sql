USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ClearCADNotProcessed]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ClearCADNotProcessed]
AS

DELETE from CADSOURCEUNITS WHERE ps_ORDERLINES_RID in (
select ps_OrderLines_RID from CADTRANSACTIONS where ps_TargetUnit_RID IS NULL)

DELETE from CADSOURCELENGTHS WHERE ps_ORDERLINES_RID in (
select ps_OrderLines_RID from CADTRANSACTIONS where ps_TargetUnit_RID IS NULL)

DELETE from CADTRANSACTIONS where ps_TargetUnit_RID IS NULL

DELETE FROM CADDRILLS WHERE noOrderLines = 0
GO
