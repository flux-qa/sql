USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReturnQuoteTallyAsString]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE procedure [dbo].[ReturnQuoteTallyAsString]
@quoteID    integer,
@out        varchar(max) OUTPUT

as

select @out = dbo.quoteTallyToString(@quoteID)
GO
