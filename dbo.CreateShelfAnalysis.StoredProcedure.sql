USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateShelfAnalysis]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateShelfAnalysis]

as

delete from ShelfAnalysis

insert into ShelfAnalysis (ID, BASVERSION, BASTIMESTAMP, 
shelf, eastOrWest, code, item, maxLen, noUnits, noMaxLen, status, noDigs)




select  next value for myseq, 1, getdate(),
shelf, eastOrWest, code, item, maxLen, case when status = 'Empty' then null else noUnits end, 
case when status = 'Empty' then null else noMaxLen end, status, noDigs

from (select  S.shelf, max(S.eastOrWest) as eastOrWest,
    I.oldCode as code, I.internalDescription as item,
    UML.maxlen, max(case when U.ID is null and U2.ID is null then 'Empty'
    when U2.ID is not null then 'Diff. Item/Len'
    else '' end) as status, max(nodigs) as nodigs,
	count(*) as noUnits, count(Distinct ISNULL(U.longLength, U2.longLength)) as noMaxLen

    from ShelfMaster S left outer join UndigByMaxLen UML on UML.location = S.shelf
    left outer join Items I on UML.ob_Items_RID = I.ID
    left outer join Units U on U.location = S.shelf and U.ob_Items_RID = I.ID and U.longlength = UML.maxLen
		and U.UMStock > 0 and U.lostFlag = 0
    left outer join Units U2 on U2.location = S.shelf and  (U2.ob_Items_RID <> I.ID or U2.longlength <> UML.maxLen) 
		and U2.UMStock > 0 and U2.lostflag = 0


     left outer join (select itemID, count(*) as noDigs        
        from (select U.ob_Items_RID as itemID,  
        max(case when L.originalQty > 0 then L.length else 0 end) as maxLen
        from CADTransactions T inner join CADDrills D on T.ps_CADDrills_RID = D.ID
        inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
        inner join Units U on L.ob_Units_RID = U.ID
        where D.designDate > dateadd(dd, -365, getdate())
        group by U.ob_Items_RID, D.ID) as T
        group by itemID) as Z on Z.itemID = I.ID 


	group by S.shelf, I.oldCode, I.internalDescription, UML.maxLen) as Z
GO
