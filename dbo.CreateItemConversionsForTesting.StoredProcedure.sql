USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateItemConversionsForTesting]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateItemConversionsForTesting]
as

delete from ITEMCONVERSIONS

INSERT INTO [dbo].[ITEMCONVERSIONS]([ID], [BASVERSION], [BASTIMESTAMP], 
[ps_UMCode_REN], [ps_UMCode_RID], [ps_UMCode_RMA], 
[defaultUM], [LFtoUM], [quoting], [purchasing], [ob_Items_REN], 
[ob_Items_RID], [ob_Items_RMA], [costPerString], [costPer]) 
select item, 1, getDate(),
    'UMCodes', U.ID, null, 1, 
    I.LFtoUM, 1, 1, 'Items', I.item, 'om_ItemConversions', 'M', 1000
    from ALC.dbo.Items I inner join UMCODES U on I.UM = U.UM 


INSERT INTO [dbo].[ITEMCONVERSIONS]([ID], [BASVERSION], [BASTIMESTAMP], 
[ps_UMCode_REN], [ps_UMCode_RID], [ps_UMCode_RMA], 
[defaultUM], [LFtoUM], [quoting], [purchasing], [ob_Items_REN], 
[ob_Items_RID], [ob_Items_RMA], [costPerString], [costPer]) 
select item+7000, 1, getDate(),
    'UMCodes', U.ID, null, 1, 
    I.LFtoUE, 1, 1, 'Items', I.item, 'om_ItemConversions', 'M', 1000
    from ALC.dbo.Items I inner join UMCODES U on I.UE = U.UM and 
    I.UM <> I.UE 


INSERT INTO [dbo].[ITEMCONVERSIONS]([ID], [BASVERSION], [BASTIMESTAMP], 
[ps_UMCode_REN], [ps_UMCode_RID], [ps_UMCode_RMA], 
[defaultUM], [LFtoUM], [quoting], [purchasing], [ob_Items_REN], 
[ob_Items_RID], [ob_Items_RMA], [costPerString], [costPer]) 
select item+14000, 1, getDate(),
    'UMCodes', U.ID, null, 1, 
    I.LFtoUP, 1, 1, 'Items', I.item, 'om_ItemConversions', 'M', 1000
    from ALC.dbo.Items I inner join UMCODES U on I.UP = U.UM and 
    I.UM <> I.UE and I.UM <> I.UP and I.UE <> I.UP

declare @UID integer
select @UID = ID from UMCODES where UM = 'LF'

-- NOW CREATE A LF CONVERSION FOR ALL FBM
INSERT INTO [dbo].[ITEMCONVERSIONS]([ID], [BASVERSION], [BASTIMESTAMP], 
[ps_UMCode_REN], [ps_UMCode_RID], [ps_UMCode_RMA], 
[defaultUM], [LFtoUM], [quoting], [purchasing], [ob_Items_REN], 
[ob_Items_RID], [ob_Items_RMA], [costPerString], [costPer]) 
select item+21000, 1, getDate(),
    'UMCodes', @UID, null, 1, 
    1, 1, 1, 'Items', I.item, 'om_ItemConversions', 'E', 1
    from ALC.dbo.Items I where I.UM = 'FBM'


select count(*) from ITEMCONVERSIONS
GO
