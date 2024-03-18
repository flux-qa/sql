USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ComputeReturnsDiscountPct]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ComputeReturnsDiscountPct]

@ID     integer,
@pct    integer OUT

as



declare @subTotal   float,
        @discount   float


select @subTotal = sum(I.subTotal), @discount = sum(I.totalDiscount)

    from Returns R inner join OrderLines L on R.ob_OrderLines_RID = L.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Invoices I on I.ps_OrderNumber_RID = O.ID
    where R.ID = @ID
    group by O.ID
    
    
IF @discount = 0 or @discount IS NULL or @subTotal = 0
    SET @pct = 0
ELSE
    set @Pct = round(100.0 * @discount / @subtotal, 0)
    
set @pct = 0    -- USED TO COMMENT OUT THE LOGIC
GO
