USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadSubstituteSourceUnits]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadSubstituteSourceUnits]

    @sourceUnit integer = 674037,
    @length     integer = 10

-- Last Change 11/28/23

    as
    
    DELETE from SubstituteUnits
    
    Insert into SubstituteUnits (ID, BASVERSION, BASTIMESTAMP, unit, unitTally, ps_OrderLines_REN, ps_OrderLines_RID)


    Select row_Number() over (order by Z.unit) as ID, 1 as BASVERSION, getdate() as BASTIMESTAMP,
    Z.unit, Z.unitTally, Z.ps_OrderLines_REN, Z.ps_OrderLines_RID
    from Units U inner join Items I on U.ob_Items_RID = I.ID
    inner join PurchaseLines PL on U.ps_PurchaseLines_RID = PL.ID
    inner join PurchaseOrders PO on PL.ob_PurchaseOrders_RID = PO.ID
    
    inner join (select Unit, I.ID as itemNo, U.location, U.UMStock, U.dateReceived, 
        PO.ob_Vendors_RID as vendorNo, dbo.unitTallyToString(U.ID) as unitTally,
        case when L.ID IS NULL then NULL else 'OrderLines' end as ps_OrderLines_REN, L.ID as ps_OrderLines_RID
        from Units U inner join Items I on U.ob_Items_RID = I.ID
        inner join PurchaseLines PL on U.ps_PurchaseLines_RID = PL.ID
        inner join PurchaseOrders PO on PL.ob_PurchaseOrders_RID = PO.ID
        left outer join OrderLines L on U.ps_OrderLines_RID = L.ID
        where U.UMstock > 0  and U.lostFlag = 0
        and U.ID in (select ob_Units_RID from UnitLengths where length = @length)
        
        ) as Z 
            on I.ID = Z.itemNo and 
            --(U.location = Z.location OR U.lastLocation = Z.location) and 
            PO.ob_Vendors_RID = Z.vendorNo
            and U.unit <> Z.unit 

            and U.ps_OrderLines_RID is null
    
    where U.unit = @sourceUnit
GO
