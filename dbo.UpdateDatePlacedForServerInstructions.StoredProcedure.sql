USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateDatePlacedForServerInstructions]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateDatePlacedForServerInstructions]
@area           varchar(5),
@designDate     date,
@drillNumber    integer,
@userID         integer

as

Update ServerInstructions

set placed = 1, datePlaced = getdate(), ps_RegularUser_REN = 'RegularUser', ps_RegularUser_RID = @userID
from ServerInstructions SI inner join ServerUnitsForLocation SUFL on SI.sourceUnit = SUFL.unit
where SI.designDate = @designDate and SI.drillNumber = @drillNumber
GO
