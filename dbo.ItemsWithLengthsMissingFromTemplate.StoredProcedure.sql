USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ItemsWithLengthsMissingFromTemplate]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ItemsWithLengthsMissingFromTemplate]

as



select row_number() over (order by I.ID) as ID, 1 as BASVERSION, getDate() as BASTIMESTAMP,
I.ID, I.oldCode, I.internalDescription as item, Z.length

    from Items I inner join (select U.ob_Items_RID, length 
        from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
        where L.qtyOnHand > 0 group by U.ob_Items_RID, length) as Z
        ON I.ID = Z.ob_Items_RID
    left outer join Templates T on T.ob_Items_RID = I.ID and T.length = Z.length
    where T.length is null
    order by I.internalDescription, Z.length
GO
