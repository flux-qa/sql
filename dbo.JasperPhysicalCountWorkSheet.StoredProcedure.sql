USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[JasperPhysicalCountWorkSheet]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[JasperPhysicalCountWorkSheet]
              
@keyword    varchar(100) = '',
@keyword2   varchar(100) = '',
@location   varchar(10) = '',
@condition  varchar(10) = '',
@itemCode   varchar(6) = '',
@consignmentFlag    integer = 0

as        
        
set @keyword = '%' + RTRIM(LTRIM(@keyword)) + '%'       
set @keyword2 = '%' + RTRIM(LTRIM(@keyword2)) + '%' 
set @location = RTRIM(LTRIM(@location)) + '%' 
set @condition = '%' + RTRIM(LTRIM(@condition)) + '%'
set @itemCode = RTRIM(LTRIM(@itemCode)) + '%'

select I.ID as itemID, I.oldCode, I.internalDescription as item,
    U.ID as unitID, U.unit as unitNumber, ISNULL(Upper(RTRIM(U.location)),'') as location, ISNULL(U.condition,'') as condition, ISNULL(U.manuf,'') as manuf,
    U.UMStock, I.UM, U.LFStock, U.piecesStock, round(1.0 * U.LFStock / U.piecesStock, 1) as avgLength,
    U.shortLongEorOString as EorO, cast (U.dateReceived as date) as dateReceived, 
    case when U.nested = 1 or U.nested2 = 1 or U.nested3 = 1 or U.nested4 = 1 then 1 else 0 end as nested,
    case when unitType = 'I' then 'Intact' else '' end as unitType,
    case when unitType = 'I' then '' else 'Opened' end as opened,
    case when OL.designStatus = 'W/P' then 'Tank' else '' end as tankMsg

    from Units U inner join Items I on U.ob_Items_RID = I.ID
    left outer join OrderLines OL on U.ps_OrderLines_RID = OL.ID
    

where U.piecesStock > 0 AND U.lostFlag <> 1

AND
(@keyword = '%%' or I.internalDescription like @keyword) AND
(@keyword2 = '%%' or I.internalDescription like @keyword2) AND
(@location = '%' or U.location like @location) AND
(@condition = '%%' or U.condition like @condition) AND
(@itemCode = '%' or I.oldCode like @itemCode) AND
(@consignmentFlag = 0 OR 
    (@consignmentFlag = 1 and U.consignmentFlag <> 1) OR 
    (@consignmentFlag = 2 and U.consignmentFlag = 1))

order by  UPPER(RTRIM(U.location)), U.unit
GO
