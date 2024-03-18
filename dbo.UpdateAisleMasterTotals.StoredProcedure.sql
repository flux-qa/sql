USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateAisleMasterTotals]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateAisleMasterTotals]

as

declare @designDate date =  cast( getdate( ) as date )
UPDATE AisleMaster
SET
  noUnits = 0,
  noBays = 0
  
UPDATE AisleMaster
SET
  noUnits = Y.noUnits,
  noBays = Y.noBays from AisleMaster A inner join
(
    SELECT
      area,
      count( distinct location ) as noBays,
      count( distinct unit ) as noUnits
    FROM
    (
        SELECT
          distinct left( U.location,1 ) AS area,
          U.location,
          U.unit,
          0 as wholeUnit
        FROM
          CADSOURCEUNITS SU
        JOIN UNITS U
         ON SU.ps_Unit_RID = U.ID
        JOIN CADDRILLS CD
         ON CD.ID = SU.ps_CADDrills_RID
        JOIN OrderLines L
         ON SU.ps_OrderLines_RID = L.ID
        LEFT JOIN NewHandleOrders NHO
         ON NHO.ps_OrderLines_RID = L.ID
        LEFT JOIN OrderUnits OU
         ON OU.ps_Units_RID = U.ID
        LEFT JOIN
        (
            SELECT
              distinct CSU.ps_Unit_RID
            FROM
              CADSOURCEUNITS CSU
            JOIN ORDERLINES OL
             ON CSU.ps_OrderLines_RID = OL.ID
            JOIN CADDrills CD
             ON CSU.ps_CADDrills_RID = CD.ID
            WHERE CD.designDate = @designdate
            AND OL.wholeUnits = 0
            AND OL.designStatus = 'Des'
        ) as Z
         ON Z.ps_Unit_RID = U.ID
        WHERE CD.designDate = @designDate
        AND ( OU.wholeUnitAssigned is null or OU.wholeUnitAssigned <> 1 )
        AND ( ( len( U.location ) = 3 AND( left( U.location,1 ) <> 'C' ) OR left( U.location,2 ) = '0R' or left( U.location,2 ) = '1L' )
        OR ( len( U.location ) = 4 and( left( U.location,1 ) < '0' or left( U.location,1 ) > '9' ) ) )

            UNION ALL
        SELECT
          distinct left( U.location,1 ) AS bay,
          U.location,
          U.unit,
          1 as wholeUnit
        FROM
          ORDERUNITS OU
        JOIN ORDERLINES L
         ON OU.ob_OrderLines_RID = L.ID
        JOIN UNITS U
         ON OU.ps_Units_RID = U.ID
        JOIN CADDRILLS CD
         ON CD.ID = OU.ps_CADDrills_RID
        WHERE CD.designDate = @designDate
        AND OU.wholeUnitAssigned = 1
        AND ( ( len( U.location ) = 3 AND left( U.location,1 ) <> 'C' )
        OR ( len( U.location ) = 4 and( left( U.location,1 ) < '0' or left( U.location,1 ) > '9' ) ) )
    ) as Z
    GROUP BY area
) as Y on A.aisleLeft = Y.area or A.aisleRight = Y.area
GO
