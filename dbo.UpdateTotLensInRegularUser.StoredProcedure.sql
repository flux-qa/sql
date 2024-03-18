USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateTotLensInRegularUser]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create Procedure [dbo].[UpdateTotLensInRegularUser]
as 
 declare @totLens integer
 select @totLens = count(*) 

    from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
    where qtyOnHand > 0  
    
 update regularuser set totlenswithstock = @totLens
GO
