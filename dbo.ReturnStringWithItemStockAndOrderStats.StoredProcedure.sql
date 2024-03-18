USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReturnStringWithItemStockAndOrderStats]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReturnStringWithItemStockAndOrderStats]
@oldCode    varchar(5),
@ret        varchar(3000) out

as

with w as (select  max(UMStock) as stock,  max(UMPocketwood) as pw, max(I.UM) as UM,
count(*) as noUnshipped, sum(UMOrdered) as unshipped

from items I inner join orderLines L on L.ob_Items_RID = I.ID
where oldCode = @oldCode AND
I.UMPocketWood > 0 and L.UMShipped = 0 and L.wrd = 'W')

select @ret = 'There is <b>' + format(w.stock - w.pw, '###,##0') + ' ' + w.um + '</b> available.<br>' +
'There is <b>' + format(w.pw, '###,###') + w.um + '</b> in PocketWood.<br>' +
'<b>' + format(noUnshipped, '##') + '</b> unShipped Orders totalling <b>' + format(unshipped, '###,##0') + ' ' + w.um + '</b>.'

from w
GO
