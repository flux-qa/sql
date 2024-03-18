USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateBayTotals]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateBayTotals]

-- last change 03/01/23 to add 2" per unit in each bay.
-- last change 10/25/23 -- Added UML OverrideMaxLen to Logic

as

-- CLEAR THE BAY TOTALS
Update BayTotals set noUnits = 0, totUM = 0, totInches = 0, noItems = 0, availableInches = inchesHigh
Update BayTotals set availFeetInches = dbo.inchesToFeet(availableInches)

-- COMPUTE INCHES USED IN EACH BAY
Update BayTotals set noUnits = Z.noUnits, noItems = Z.noItems, totUM = Z.totUM, totInches = isNULL(Z.totInches,0) + 2 * Z.noUnits
from BayTotals B inner join
    (select location, count (distinct ob_items_RID) as noItems, count(*) as noUnits, sum(U.UMStock) as totUM,
    sum(case when UML.overrideMaxLen > 0 THEN UML.overrideMaxLen
    when UML.inchesHigh > 36 then 36
    when UML.inchesHigh is null then I.CADMaxHeightPcs * D.inchesHigh 
    else UML.inchesHigh end) as totInches
    from Units U inner join Items I on U.ob_Items_RID = I.ID
    left outer join UnitMaxLenData UML on UML.ob_Item_RID = I.ID and UML.maxLength = U.longLength
    left outer join Dim1ToInches D on I.dim1 = D.dim1    
    where U.UMStock > 0 AND U.lostflag = 0
    group by location) as Z on B.bay = Z.location
    
Update BayTotals set availableInches = inchesHigh - totInches
Update BayTotals set availFeetInches = dbo.inchesToFeet(availableInches)
GO
