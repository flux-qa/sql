USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateMissingTemplateLengths]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateMissingTemplateLengths]
as



declare @IDSeed integer

select @IDSeed =  max(id) from templates where id < 10000
;

with w as (select distinct  I.ID,   L.length
    from Units U inner join UnitLengths L on U.ID = L.ob_units_RID
    inner join Items I on U.ob_Items_RID = I.id
    left outer join Templates T on T.ob_Items_RID = U.ob_items_RID and T.length = L.length
    where L.qtyOnHand > 0 AND T.length is null)

insert into templates (ID, BASVERSION, BASTIMESTAMP, ob_Items_REN, ob_Items_RID, ob_Items_RMA, length,
    suggestedPct, fudgeFactor)
select @IDSeed + row_number() over (order by ID, Length), 1, getDate(), 'Items', ID, null, length,
    0, 25
from w
GO
