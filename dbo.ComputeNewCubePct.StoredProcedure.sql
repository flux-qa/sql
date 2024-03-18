USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ComputeNewCubePct]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ComputeNewCubePct]

as

-- SAVE THE CUBE CALC FROM WHEN ORDER WAS ENTERED
Update OrderLines set BMEsperFT3Original = BMEsperFT3
    where BMEsperFT3Original is null
    

update OrderLines set BMESperFT3 = round(100.0 * Y.totalLF / I.LFperCube / 2336,6) 
from OrderLines L inner join Items I on L.ob_Items_RID = I.ID
inner join (select L.ID, 
    sum(T.pieces * case when T.length * 2 < Z.maxLen then T.length else Z.maxLen end) as totalLF
        from OrderLines L inner join orderTally T on T.ob_OrderLines_RID = L.ID
    
         inner join (select L.ID, max(T.length) as maxlen
            from OrderLines L inner join OrderTally T on T.ob_OrderLines_RID = L.ID
            where L.UMShipped = 0 and T.pieces > 0 and L.wholeUnits = 0
            group by L.ID) as Z on T.ob_OrderLines_RID = Z.ID
        group by L.ID) as Y on L.ID = Y.ID  
where I.LFperCube > 0 AND L.ps_PurchaseLines_RID is null and L.SRO = 'S'
GO
