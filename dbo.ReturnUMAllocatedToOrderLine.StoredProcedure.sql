USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReturnUMAllocatedToOrderLine]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReturnUMAllocatedToOrderLine]

@orderLineID    integer = 1853232,
@UMAllocated    integer out

as

select @UMAllocated = round(1.0 * sum(length * qtyOnHand) / max(I.LFperUM),0) 
    from Units U inner join UnitLengths L on L.ob_Units_RID = U.ID
    inner join Items I on U.ob_Items_RID = I.ID
    where U.ps_OrderLines_RID = @orderLineID
GO
