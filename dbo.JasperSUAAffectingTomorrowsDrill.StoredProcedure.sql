USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[JasperSUAAffectingTomorrowsDrill]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[JasperSUAAffectingTomorrowsDrill]



@from   date = '06/06/2023'


as


select 
I.oldcode as code, I.internalDescription as item, 
U.unit, SUA.length, SUA.take as old, SUA.took as new,
T.take, T.balance as CADBalance, L.qtyOnHand as unitBalance,
R.LoginName as who
from SourceUnitAdjustmentLog SUA inner join UnitLengths L on SUA.ps_SourceUnitLength_RID = L.ID
inner join Units U on L.ob_Units_RID = U.ID
inner join Items I on U.ob_Items_RID = I.ID
inner join RegularUser R on SUA.ps_RegularUser_RID = R.ID
inner join CADTransactions T on T.ps_UnitLengths_RID = L.ID
inner join CADDrills D on T.ps_CADDrills_RID = D.ID
where  cast(SUA.entered as date) = @from and D.designDate > @from
-- ADDED 06/19/23 -- ONLY SHOW SUA's WHERE Delta SUA.Take > CADBalance
and (SUA.take - SUA.took) > T.balance

order by I.oldcode, U.unit, SUA.length
GO
