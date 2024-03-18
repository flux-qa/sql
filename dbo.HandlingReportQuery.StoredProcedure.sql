USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[HandlingReportQuery]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HandlingReportQuery]
@drillID integer = 10865142

-- 2/15/22  ADDED JOIN TO UNDIGBYMAXLEN AND LOGIC TO USE THAT FOR UNDIG LOCATION

as 

select coalesce(L.designerComments,'') as comments, coalesce(L.designComments,'') as designComments, 
L.lineNumber, L.orderNumber, L.customerQty, L.customerUM,  L.CADHigh, L.CADWide, L.CADPlus, 
L.CADTotalPieces, L.tripNumber, L.designerComments, L.tank, I.internalDescription, I.oldcode, I.CADHandle, 
case when UML.location is null or UML.location = '' then coalesce(S.undigTo,'') else UML.location end as CADUnDigTo, 
I.CADWidthPieces, I.UM, C.name, C.add1, C.add2, C.city, C.state, C.zip, C.fieldRep, 
coalesce(C.designComments,'') as customerDesignComments,
T.length, T.take, T.takeAll, T.balance, T.unitNumber,
case when T.modifier = '=' then 'EXACT'
when T.modifier = '<' then 'Max' 
when T.modifier = '>' then 'Min' else '' end as modifier,
U.unit as targetUnit, U.location as targetLocation, U.undigTo as targetUndigTo, 
I.CADHandle as targetHandleArea, U.unit as targetNumber, Z.minTarget, Z.maxTarget, U.UMStock as targetStock,
S.unit as sourceUnit, S.location as sourceLocation, S.condition as sourceCondition, 
case when UML.location is null or UML.location = '' then coalesce(S.undigTo,'') else UML.location end as sourceUndigTo, 
UL.length as sourceLength, UL.qtyOnHand,
CD.drillNumber, CD.designDate, U.shortLength, U.longLength, L.noTargets, newTargetNumber, numberOfTargets, U.LFStock,
U.piecesStock, dbo.substituteUnit(S.unit) as substituteUnits, '' as side


from ORDERLINES L 
inner join ORDERS O on L.ob_Orders_RID = O.ID
inner join ITEMS I on L.ob_Items_RID = I.ID
inner join CUSTOMERS C on O.ob_Customers_RID = C.ID
inner join CADTRANSACTIONS T on T.ps_OrderLines_RID = L.ID
inner join UNITS U on T.ps_TargetUnit_RID = U.ID
inner join UNITLENGTHS UL on T.ps_UnitLengths_RID = UL.ID
inner join UNITS S on UL.ob_Units_RID = S.ID
inner join CADDRILLS CD on CD.ID = L.ps_CADDrills_RID
left outer join UnDigByMaxLen UML on UML.ob_Items_RID = I.ID and UML.maxlen = S.longLength

-- FOLLOWING DETERMINES IF SOURCE USED IN MORE THAN ONE TARGET
inner join (select S.ID, min(U.unit) as minTarget, max(U.unit) as maxTarget
    from CADTRANSACTIONS T 
   inner join UNITS U on T.ps_TargetUnit_RID = U.ID
    inner join UNITLENGTHS UL on T.ps_UnitLengths_RID = UL.ID
    inner join UNITS S on UL.ob_Units_RID = S.ID
    where ps_CADDrills_RID = @drillID
    group by S.ID) as Z on Z.ID = S.ID
    
-- FOLLOWING GIVES SEQUENCE # FOR TARGETS FOR EACH HANDLING AREA
 inner join ( select ID, row_number() over (partition by handleArea order by ID) as newTargetNumber
	from (select distinct U.ID, U.handleArea
    from CADTRANSACTIONS T 
    inner join UNITS U  on T.ps_TargetUnit_RID = U.ID
    inner join ORDERLINES L  on U.ps_OrderLines_RID = L.ID
   where L.ps_CADDrills_RID = @drillID  
   and L.designStatus = 'Des' 
   ) as x1	
      )   as FEE on FEE.ID = U.ID
 
 inner join (select I.CADHandle, count(distinct ps_TargetUnit_RID) as numberOfTargets
    from CADTRANSACTIONS T inner join Units U on T.ps_TargetUnit_RID = U.ID
    inner join Items I on U.ob_Items_RID = I.ID
    where ps_CADDrills_RID = @drillID
    group by I.cadHandle) as TotTarg on TotTarg.CADHandle = I.CADHandle
 
where L.ps_CADDrills_RID = @drillID
    and L.designStatus = 'Des'

order by I.CADHandle, U.targetNumber,  U.unit, S.unit, UL.length desc
GO
