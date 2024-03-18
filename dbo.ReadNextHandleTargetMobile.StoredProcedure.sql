USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadNextHandleTargetMobile]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadNextHandleTargetMobile]
@EastOrWest     varchar(1)

-- last change 02/23/24

as

select CD.ID as cadDrillID, CD.designDate, CD.drillNumber,
C.name, C.add1, C.city, C.state, C.zip, L.orderLineForDisplay, C.designComments as customerDesignComments,
    L.UMOrdered, round(Z.LFDesigned / I.LFperUM, 0) as UMDesigned, Z.LFDesigned, Z.piecesDesigned,
    M.EastOrWest, M.rowNumber, M.handlingArea, M.tank, status
    
    from HandleTargetMobile M inner join CADDrills CD on M.ps_CADDrills_RID = CD.ID
    inner join OrderLines L on M.ps_OrderLines_RID = L.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    inner join Units T on M.ps_TargetUnit_RID = T.ID 
    inner join Items I on T.ob_Items_RID = I.ID
    inner join (select ob_Units_RID as UID, sum(Length * qtyOnHand) as LFDesigned, 
        sum(QtyOnHand) as piecesDesigned from UnitLengths group by ob_Units_RID) as Z on Z.UID = T.ID
        
    inner join (select ob_HandleTargetMobile_RID as ID, count(*) as noSources, 
        sum(case when H.isPlaced = 1 then 1 else 0 end ) as noPlaced
        from HandleTargetSources H
        group by ob_HandleTargetMobile_RID) as HS on HS.ID = M.ID   
        
    where M.EastOrWest = @EastOrWest  and HS.noPlaced = HS.noSources
     
    order by M.rowNumber
GO
