USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ComputeReturnTallyTotals]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ComputeReturnTallyTotals]

@returnID integer = 1107001

as


Update Returns set UMGood = ROUND(1.0 * LFGood / I.LFperUM,0), UMBad = round(1.0 * LFBad / I.LFperUM,0)
    from Returns R inner join OrderLines L on R.ob_orderLines_RID = L.ID
    inner join Items I on L.ob_Items_RID = I.ID inner join
    
    
    (select ob_returns_RID, sum(Length * isnull(piecesGood,0)) as LFGood, sum(length * isNull(piecesBad,0)) as LFBad
    from ReturnsTally group by ob_Returns_RID) as Z on R.ID = Z.ob_returns_RID
   where R.ID = @returnID
GO
