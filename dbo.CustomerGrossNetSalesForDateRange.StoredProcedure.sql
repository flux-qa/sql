USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CustomerGrossNetSalesForDateRange]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create Procedure [dbo].[CustomerGrossNetSalesForDateRange]

    @custno     integer = 4856,
    @fromDate   date = '01/01/2020',
    @thruDate   date = '05/29/2020',
    @netSales   decimal(10,2) OUT,
    @grossSales decimal(10,2) OUT,
    @credits    decimal(10,2) OUT

as    
    
select @netSales = sum(subTotal), 
    @grossSales = sum(case when subtotal > 0 then subtotal else 0 end),
    @credits = sum(case when subtotal < 0 then subtotal else 0 end)
    from Invoices 
    where ob_Customer_RID = @custno
    and dateEntered between @fromDate and @thruDate
GO
