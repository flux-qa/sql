USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ItemSearch]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ItemSearch]

--
-- Last change 11/03/16

@searchField varchar(200) = '',
@searchField2 varchar(200) = '',
@searchField3 varchar(200) = '',
@Dim1   float = 0,
@Dim2   float = 0,
@StockOnly integer = 0,

@Product varchar(30),
@Pattern varchar(20),
@OldCode varchar(8)

as

set @OldCode = '%' + LTRIM(RTRIM(@OldCode)) + '%'

if @SearchField <> ''
    set @searchField = '%' + LTRIM(RTRIM(@searchField)) + '%'

if @SearchField2 <> ''
    set @searchField2 = '%' + LTRIM(RTRIM(@searchField2)) + '%'

if @SearchField3 <> ''
    set @searchField3 = '%' + LTRIM(RTRIM(@searchField3)) + '%'

select ID, BASVERSION, BASTIMESTAMP,
    oldCode, dim1, dim2, dim3, internalDescription, customerDescription,
    UMStock, UMAvailable, UMOpenPO, UM, LFperUM, avgCost, approxValue, 
    null as lastOrder, 
    case when UMAvailable > 0 or UMOpenPO > 0 then 0 else 1 end as sortOrder

    from ITEMS I 
    
    where 
   (UMAvailable > 0 OR @StockOnly = 0) 
    AND 
    (@searchfield = '' or I.internalDescription like @searchField)
    AND (@searchfield2 = '' or I.internalDescription like @searchField2)
    AND (@searchfield3 = '' or I.internalDescription like @searchField3)
    AND (@Dim1 = 0 OR I.dim1 = @Dim1)
    AND (@Dim2 = 0 OR I.dim2 = @Dim2)
    /*
    AND (@oldCode = '' or @OldCode IS NULL OR @OldCode = 'ALL' OR @oldCode = oldCode)
 */   
    AND (@product = 'ALL' OR 
        (@product = 'White Soft Woods' AND I.oldProduct = '0') OR
       (@product = 'Non White Soft Woods' AND I.oldProduct = '1') OR
       (@product = 'HardWoods' AND I.oldProduct = 'H'))

   AND (@pattern = 'ALL' OR 
        (@pattern = '4 Side' AND left(I.oldPatternCode,1) = '0') OR
       (@pattern = 'Pure Vee Joint' AND left(I.oldPatternCode,1) = '1') OR
       (@pattern = 'Other T & G' AND left(I.oldPatternCode,1) = '2') OR       
       (@pattern = 'Lap Joinder' AND left(I.oldPatternCode,1) = '3') OR
       (@pattern = 'Bevel' AND @pattern = PatternCode))

   AND (@oldCode = '%%' or I.oldcode like @OldCode)


    order by sortOrder,  I.dim1, I.dim2, I.internalDescription
GO
