USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateServerUnitsForLocation]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateServerUnitsForLocation]

-- last change 12/15/23

@area           varchar(4) = 'East',
@orderNumber    varchar(20) = '490744-1'

as

delete from SERVERUNITSFORLOCATION where area = @area

Insert into ServerUnitsForLocation (ID, BASVERSION, BASTIMESTAMP,
    area, unit, maxlen, qtyUM, UM, location, placed, skipped)

select next value for mySeq, 1, getdate(), @area,
    unit, cast(maxLen as varchar(2)) + '''' as maxLen, qtyUM, UM, location, 0, 0
from (select unit, max(length) as maxLen, sum(length * qtyOnHand) / max(LFperUM) as qtyUM, max(UM) as UM, max(location) as location

from(
    select U.unit, L.length, L.qtyOnHand, S.location,  I.LFperUM, I.UM
        from SERVERINSTRUCTIONS S inner join Units U on S.sourceUnit = U.unit
        inner join UnitLengths L on L.ob_Units_RID = U.ID
        inner join Items I on U.ob_Items_RID = I.ID
        where S.orderNumber = @orderNumber
    
    
    union all
    
    select U.unit, T.length, sum(T.take) as take, max('') as location, max(0) as LFperUM, max('') as UM
        from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
        inner join Units U on L.ob_Units_RID = U.ID
        where U.unit in (select U.unit
            from SERVERINSTRUCTIONS S inner join Units U on S.sourceUnit = U.unit  
            where S.orderNumber = @orderNumber)
        group by U.unit, T.length) as Z
        group by unit) as Y
GO
