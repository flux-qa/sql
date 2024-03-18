USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateOverAllocatedItems]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateOverAllocatedItems]


as

delete from OverAllocatedItems

INSERT INTO [dbo].[OVERALLOCATEDITEMS]([ID], [BASVERSION], [BASTIMESTAMP], 
[itemID], [code], item, avail, pocket, ordered, delta, noLines, lastOrder, dateAdded)

select row_Number() over (order by I.id) as ID, 1 as BASVERSION, getdate() as BASTIMESTAMP,
I.ID as itemID, I.oldCode as code, I.internalDescription as item,
    max(UMStock) - max(UMPocketWood) as avail, 
    max(UMPocketWood) as pocket, sum(L.UMOrdered) as ordered,
    max(UMStock) - max(UMPocketWood) - sum(L.UMOrdered) as delta,
    count(*) as noLines, max(O.dateEntered) as lastOrder, max(I.dateOverAllocated)
    from OrderLines L inner join Items I on L.ob_Items_RID = I.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
    where L.UMShipped = 0 and L.WRD = 'W'
    group by I.id, I.oldcode, I.internalDescription
    having max(UMStock) - max(UMPocketWood) < sum(L.UMordered)
    order by I.oldCode
GO
