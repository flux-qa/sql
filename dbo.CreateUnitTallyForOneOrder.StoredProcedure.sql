USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateUnitTallyForOneOrder]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateUnitTallyForOneOrder]

@orderID integer = 1109290

as

delete from UnitTallyForOneOrder

insert into unitTallyForOneOrder (id, basversion, basTimestamp, orderNumber, unit, qty, tally)

select row_number() over (order by U.unit), 1, getdate(),
RTRIM(LTRIm(cast (L.ob_Orders_RID as char(7)))) + '-' + rtrim(ltrim(cast(l.lineNumber as char(2)))) as orderNumber,
 U.unit, format(isNull(U.UMStock,0) + isNull(U.UMShipped,0), '###,##0') + ' ' + I.UM as qty,
dbo.UnitTallyPlusShippedToString(U.ID) as tally

    from Units U inner join OrderLines L on U.ps_OrderLines_RID = L.ID
    inner join Items I on U.ob_Items_RID = I.ID
    
    where L.ob_Orders_RID = @orderID AND (L.designStatus = 'W/P' or L.dateShipped IS NOT NULL)
GO
