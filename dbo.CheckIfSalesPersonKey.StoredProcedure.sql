USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CheckIfSalesPersonKey]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CheckIfSalesPersonKey]

@salesRep   varchar(6) = 'sk',
@itemID     integer = 4526,
@maxQty     integer  out

as
        
select @maxQty = isNull(maxQty,0) from SalesPersonKeyToSellPocketWood
        where UPPER(@salesRep) = UPPER(salesRepInitials) and ps_Items_RID = @itemID
GO
