USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadServiceChargeDescription]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create Procedure [dbo].[ReadServiceChargeDescription]

@orderLineID integer = 1850075,
@description varchar(max) OUT

as


select @description = dbo.ServiceChargeDescripionFor1Line(@orderLineID)
GO
