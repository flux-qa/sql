USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ProcessConsignmentUnitsInDesign]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE procedure [dbo].[ProcessConsignmentUnitsInDesign]

-- Create Consignment Transactions for any orderline that used consignment units as sources

@orderLineID integer = 8214050
     
as

INSERT INTO [dbo].[CONSIGNMENTTRANSACTIONS]([ID], [BASVERSION], [BASTIMESTAMP],
[cost], [pieces], [qtyUM], [action], dateEntered, description,
[ps_User_REN], [ps_User_RID], [ps_User_RMA], 
[ps_PurchaseLine_REN], [ps_PurchaseLine_RID], [ps_PurchaseLine_RMA], 
[ps_Units_REN], [ps_Units_RID], [ps_Units_RMA], 
[ps_Items_REN], [ps_Items_RID], [ps_Items_RMA])   
    
    select next value for MySeq, 1, getdate(), 
        U.actualCost, 
        Z.totalPcs, ROUND(1.0 * + Z.totalLF / I.LFperUM,0), 
        'Purchased from Stock', getdate(), 
        'Unit: ' + rtrim(cast(U.unit as char(8))) + ' Used for Design Order: ' + rtrim(OL.orderLineForDisplay),
        'RegularUser', 2, null,
        null, null, null,
        'Units', unitID, null,
        'Items', I.ID, null
        from Units U inner join Items I on U.ob_Items_RID = I.ID
        inner join OrderLines OL on @orderLineID = OL.ID
        inner join (select U.ID as unitID, OL.ID as orderLineID, sum(T.take) as totalPcs, sum(L.length * T.take) as totalLF  
            from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
             inner join Units U on L.ob_Units_RID = U.ID
             inner join OrderLines OL on T.ps_OrderLines_RID = OL.ID
             inner join CADDrills D on T.ps_CADDrills_RID = D.ID
             where OL.ID = @orderLineID and U.consignmentFlag = 1
             group by U.ID, OL.ID) as Z on Z.unitID = U.ID
         WHERE I.LFperUM > 0
GO
