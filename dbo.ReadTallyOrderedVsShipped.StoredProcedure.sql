USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadTallyOrderedVsShipped]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadTallyOrderedVsShipped]

@orderLineID integer = 1807187

as

delete from TallyOrderedVsShipped where ps_OrderLines_RID = @orderLineID


INSERT INTO [dbo].[TallyOrderedVsShipped]([ID], [BASVERSION], [BASTIMESTAMP],
 [ps_OrderLines_REN], [ps_OrderLines_RID], [ps_OrderLines_RMA],
 lengthString, Pieces, pct, shipped, pctShipped, costDeltaPct, costDelta, modifier)

    select next Value For BAS_IDGEN_SEQ over (order by T.length), 1, getdate(), 
    'OrderLines', L.ID as ps_OrderLines_RID, null,
    '<b>' + RTRIM(CAST(T.length as char(3))) + '''</b>', T.pieces, T.pct, Z.shipped, 
        case when L.umShipped = 0 then 0 else
        round(100.00 * Z.length * z.shipped / I.LFperUM / L.umShipped,1 ) end as pctShipped, 
        T.costDeltaPct, IT.costDelta, T.Modifier
        from OrderTally T inner join OrderLines L on T.ob_OrderLines_RID = L.ID
        inner join Items I on L.ob_Items_RID = I.ID
        inner join Templates IT on IT.ob_Items_RID = I.ID and IT.length = T.length
        full outer join
         (select length, sum(qtyShipped) as shipped 
            from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
            where U.ps_OrderLines_RID = @orderLineID group by length) as Z on T.length = Z.length
        
        where L.id = @orderLineID
        and (T.pieces > 0 or Z.shipped > 0)
GO
