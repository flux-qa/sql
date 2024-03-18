USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CADDeleteTransactionsNOTProcessed]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CADDeleteTransactionsNOTProcessed]

as

delete from CADTransactions where designAccepted = 0
GO
