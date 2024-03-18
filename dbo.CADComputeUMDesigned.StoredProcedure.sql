USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CADComputeUMDesigned]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CADComputeUMDesigned]  
@orderLineID integer,
@UMDesigned integer OUTPUT,
@piecesDesigned integer OUTPUT

as

set nocount ON;


declare @LFperUM Float

Select @LFperUM = ISNULL(I.LFperUM,0)
    from OrderLines L inner join Items I on L.ob_Items_RID = I.ID
    where L.ID = @OrderLineID

IF @LFperUM > 0
Select @UMDesigned = ROUND(SUM(length * (pieces - CADBalance)) / @LFperUM,0),
    @piecesDesigned = sum(pieces - CADBalance)
    from ORDERTALLY T 
    where T.ob_OrderLines_RID = @OrderLineID
GO
