USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CADCreateSourceLengths]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CADCreateSourceLengths]  
 
@UnitID     integer,
@OrderLine  integer


-- LAST CHANGE 05/25/18 -- changed param from orderLine to unitID
-- CALLED AFTER DESIGN RUN

-- LAST CHANGE 02/21/19 FOR SEQUENCE

AS


delete from CADSOURCELENGTHS where Unit = @UnitID

insert into CADSOURCELENGTHS 
    (ID, BASVERSION, BASTIMESTAMP,
    ps_OrderLines_REN, ps_OrderLines_RID, ps_OrderLines_RMA,
    length, lengthString, pieces, take, originalTake, takeAll, balance, unit, available,
    ps_UnitLengths_REN, ps_UnitLengths_RID, ps_UnitLengths_RMA)

    select NEXT VALUE FOR BAS_IDGEN_SEQ, 1, getDate(),
        'OrderLines', @ORDERLINE, null,
        L.length, '<b>' + RTRIM(CAST(L.length as char(2))) + '</b>''',    
        L.qtyOnHand, coalesce(C.take,0), coalesce(C.take,0), 
        coalesce(C.takeAll,0), L.qtyOnHand - coalesce(C.take,0) as balance, L.ob_Units_RID, T.piecesAvailable,
        'UnitLengths', L.ID, null
        
    from UNITLENGTHS L
        left outer join ORDERTALLY T on T.length = L.length and T.ob_OrderLines_RID = @OrderLine
        LEFT OUTER join CADTRANSACTIONS C on L.ID = C.ps_UnitLengths_RID
        and C.ps_OrderLines_RID = @OrderLine

    where L.ob_Units_RID = @UnitID
GO
