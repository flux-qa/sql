USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CADCreateSourceUnit]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CADCreateSourceUnit]   

-- LAST CHANGE 09/01/16

-- LAST CHANGE 02/21/19 FOR SEQUENCE


@unitID         integer,
@orderLineID    integer,
@inPlayFlag     integer,
@designDate     dateTime

as

print 'creating source unit  ' + cast(@unitID as char(10)) + '  ' + convert(char(30), getDate(), 108)

;

with w as (select U.ID as unit,
sum(coalesce(take,0)) as taken, 
sum(case when take is not null then 1 else 0 end) as noLengths, 
sum(qtyOnHand) as pieces
    from UNITLENGTHS L inner join UNITS U on L.ob_Units_RID = U.ID
    left outer join CADTRANSACTIONS T on T.unitNumber = U.unit and T.length = L.length and T.ps_OrderLines_RID = @orderLineID
    where U.ID = @unitID 
    group by U.ID)

INSERT INTO CADSOURCEUNITS (
[ID], [BASVERSION], [BASTIMESTAMP], 
 [ps_Unit_REN], [ps_Unit_RID], [ps_Unit_RMA], 
[ps_OrderLines_REN], [ps_OrderLines_RID], [ps_OrderLines_RMA], 
pieces, taken, balance,  noLengths, designAccepted, workPapersProcessed,
dateDesigned, inPlay, designDate) 

    select NEXT VALUE FOR BAS_IDGEN_SEQ , 1, getDate(),
    'Units', @unitID, null,
    'OrderLines', @orderLineID, null, 
    pieces, taken, pieces - taken, noLengths, 0, 0,
    getDate(), @inPlayFlag, @designDate
    from w
GO
