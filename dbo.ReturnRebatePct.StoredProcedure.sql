USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReturnRebatePct]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReturnRebatePct]

@customer       integer, 
@billTo         integer, 
@item           integer,
@rebatePct      float OUT

as

declare @association integer

select @association = ISNULL(R.ID, -1) 
    from CustomerRelations R inner join CustomerBillToLink CBL on R.ID = CBL.ob_CustomerRelations_RID
    where CBL.ob_Customers_RID = @Customer and CBL.relationType = 'Association'
    
    select @rebatePct = isNULL(sum(RS.pctOverLevel2),0)
    from CustomerBillToRebateLink CBRL 
    inner join RebateStructure RS on RS.ID = CBRL.ob_RebateStructure_RID
    left outer join (select IG.ID as ItemGroupID, I.ID as ItemID
        from ItemGroupings IG inner join ITEMGROUPINGS_REF IR on IG.ID = IR.ID
        inner join Items I on IR.RID = I.ID) as Z on RS.ps_ItemGroupings_RID = Z.itemGroupID
    WHERE (CBRL.ps_Customers_RID = @customer OR CBRL.ps_BillTo_RID = @billTo OR CBRL.ps_BillTo_RID = @association) 
        and (Z.itemID is null or Z.itemID = @item)
GO
