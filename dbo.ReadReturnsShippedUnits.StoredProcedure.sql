USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadReturnsShippedUnits]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[ReadReturnsShippedUnits]

@orderLineID integer = 1112558

as

select row_number() over (order by U.unit) as ID, 1 as BASVERSION, getdate() as BASTIMESTAMP, 
    U.unit, isNull(U.manuf,'') as manuf, 
    format(U.UMShipped,'###,###') + ' ' + I.UM as UMShipped, dbo.UnitTallyShippedToString(U.ID) as tallyString
    from Units U inner join Items I on U.ob_Items_RID = I.ID
    where ps_OrderLines_RID = @orderLineID
    order by U.unit
GO
