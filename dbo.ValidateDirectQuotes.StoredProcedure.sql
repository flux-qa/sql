USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ValidateDirectQuotes]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ValidateDirectQuotes]


@custno integer = 7669,

@directErrorFlag integer OUT

as

declare @noSelected     integer = 0
declare @noDirects      integer = 0
declare @noPOLines      integer = 0
declare @noValidDirects integer = 0


set @directErrorFlag = 0

select @noSelected = count(*) 
    from Quotes
    where ob_Customers_RID = @custno and selectedFlag = 1

select @noPOLines = count(*)
    from PurchaseLines where ob_PurchaseOrders_RID in 
        (select distinct PL.ob_PurchaseOrders_RID 
            from PurchaseLines PL inner join Quotes Q on PL.ID = Q.ps_PurchaseLines_RID
            where ob_Customers_RID = @custno and selectedFlag = 1 )
    
select @noDirects = count(*),
    @noValidDirects = sum(case when PL.quantityOrdered = Q.customerQty then 1 else 0 end)
    from Quotes Q inner join PurchaseLines PL on Q.ps_PurchaseLines_RID = PL.ID
    inner join PurchaseOrders P on PL.ob_PurchaseOrders_RID = P.ID
    where ob_Customers_RID = @custno and selectedFlag = 1 AND P.ps_Customers_RID > 0

    
--select @noSelected, @noDirects, @noValidDirects, @noPOLines

IF @noDirects = 0 OR @noValidDirects = @noPOLines  
    SET @directErrorFlag = 0
ELSE
    SET @directErrorFlag = 0
GO
