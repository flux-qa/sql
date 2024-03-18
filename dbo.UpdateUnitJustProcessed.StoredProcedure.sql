USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateUnitJustProcessed]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateUnitJustProcessed]
@OrderLineID integer

as
    
SET NOCOUNT ON
  
    
Update Units
set  PiecesStock = coalesce(pieces,0),
     computedPieces = coalesce(pieces,0) - FLOOR(isNull(nested2,0) / 2 + isNull(nested3,0) / 3 + isNull(nested4,0) / 4 + isNull(nested5,0) / 5 + isNull(nested6,0) / 6),
     LFStock = coalesce(Z.LFStock,0),
     UMStock = round(coalesce(Z.LFStock,0) / I.LFperUM,0),
     ShortLength =  isNull(minLen,0),
     LongLength = isNull(maxLen,0),
     dateEntered = getDate(),
     dateWorkpapersProcessed = null,
     EvenOddRandom =
    CASE
     WHEN TotLength = 0 then ''
     WHEN TotLength > 0 and TotLength = EvenLength then 'E'
     WHEN TotLength > 0 and EvenLength = 0 then 'O'
     ELSE 'R'
     END,
    shortLongEorOString = case when minLen is null then '--' WHEN
    minlen = maxLen then rtrim(cast(maxLen as char(3))) + ' ' + EvenOddRandom 
        else rtrim(cast(minLen as char(3))) + '-' + rtrim(cast(maxLen as char(3))) + ' ' + EvenOddRandom end
    
from Units U inner join Items I on U.ob_Items_RID = I.ID
    inner join (select ob_Units_RID as unitID, 
    sum(qtyOnHand) as Pieces, sum(L.length * qtyOnHand) as LFStock,

    min(L.length) as minLen, max(L.length) as maxLen, count(*) as totLength, 
    sum(case when L.Length  = floor(L.Length / 2) * 2 then 1 else 0 end) as evenLength
    from unitLengths L inner join Units U on L.ob_Units_RID = U.ID
    where ps_OrderLines_RID = @OrderLineID and qtyOnHand > 0
    group by L.ob_Units_RID) as Z on U.ID = Z.unitID
    
update units set  shortLongEorOString = case when shortLength = 0 then '' WHEN
    shortLength = longLength then rtrim(cast(longLength as char(3))) + ' ' + EvenOddRandom 
        else rtrim(cast(shortLength as char(3))) + '-' + rtrim(cast(longLength as char(3))) + ' ' + EvenOddRandom end
    where ps_OrderLines_RID = @OrderLineID
GO
