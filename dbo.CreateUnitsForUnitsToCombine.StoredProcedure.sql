USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateUnitsForUnitsToCombine]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateUnitsForUnitsToCombine]
@CADDrillID integer = 1500748,
@itemID integer = 2643

as

delete from UnitsForUnitsToCombine

insert into UnitsForUnitsToCombine (ID, BASVERSION, BASTIMESTAMP,
    unit, UMStock, pieces, shortLongString, dateReceived)    
    
select U.ID, 1, getDate(), 
    U.unit, U.UMStock, U.piecesStock as Pieces, U.shortLongEorOString as shortLongString,
    U.dateEntered as dateReceived
    from Units U inner join (    
        select distinct U.ID 
        from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
        inner join Units U on L.ob_Units_RID = U.ID
        where T.ps_CADDrills_RID = @CADDrillID and L.qtyOnHand > 0 and U.ob_Items_RID = @itemID) as Z
        on U.ID = Z.ID
GO
