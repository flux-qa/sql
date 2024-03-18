USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[PostRMACredit]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PostRMACredit]

@returnID         bigint 

as

declare 
        @returnAmount   money
           

select @returnAmount = isNull(-1 * (creditAmount - isNull(restockFee,0)),0)
    from Returns where ID = @returnID

insert into invoices (ID, BASVERSION, BASTIMESTAMP, 
    ob_Customer_REN, ob_Customer_RID, ob_Customer_RMA,
    ob_BillTo_REN, ob_BillTo_RID, ob_BillTo_RMA,
    ps_OrderNumber_REN, ps_OrderNumber_RID, ps_OrderNumber_RMA,
    ps_TermsCode_REN, ps_TermsCode_RID, ps_TermsCode_RMA, 
    dateEntered,  invoiceDate, dateShipped, discountDate, dueDate,
    invoiceNumber, subTotal, salesTax, balance, seqNumber, invoiceNumberString, invoiceType,
    ps_creditCode_REN, ps_CreditCode_RID, RMANumber)



select NEXT VALUE FOR BAS_IDGEN_SEQ, 1, getDate(),
    'Customers', C.ID, 'om_Invoices',
    'CustomerRelations', B.ID, 'om_Invoices',
    'Orders', O.ID, 'ps_OrderNumber',
    'Terms', T.ID, null,
    getDate(), getDate(), getDate(), getDate(), getDate(),    
    R.RMANumber, @returnAmount,  isNull(round(0.01 * @returnAmount * C.salesTaxPct,2),0),
    @returnAmount  + isNull(round(0.01 * @returnAmount * C.salesTaxPct,2),0), 0,
    rtrim(cast(R.RMANumber as char(7))), 'Credit Memo',
    'CreditCodes', R.reasonForCredit_RID, R.RMANumber


from Returns R inner join OrderLines L on R.ob_OrderLines_RID = L.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
    inner join CustomerRelations B on O.ob_BillTo_RID = B.ID
    inner join Terms T on B.whseTerms_RID = T.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    left outer join (select invoiceNumber, max(seqNumber) as lastSeq
        from Invoices group by invoiceNumber) as Z on O.orderNumber = Z.invoiceNumber
where R.ID = @returnID
GO
