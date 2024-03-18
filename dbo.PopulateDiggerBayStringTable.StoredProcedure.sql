USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[PopulateDiggerBayStringTable]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[PopulateDiggerBayStringTable]
as

declare @ListString VARCHAR(MAX)
declare @ID integer

delete from DIGGERBAYSTRING 

declare C cursor LOCAL FAST_FORWARD for
    select distinct diggerNumber from DIGGERBAYLINK

OPEN C
fetch C into @ID
while (@@FETCH_STATUS = 0)
begin
    set @ListString = null
    select @ListString = coalesce(@ListString+'-','') + bay
        from DIGGERBAYLINK
        where diggerNumber = @ID
        order by bay

    insert into DIGGERBAYSTRING (ID, BASVERSION, BASTIMESTAMP, bayList)
    select @ID, 1, getDate(), @ListString

    fetch c into @ID
end

CLOSE C
DEALLOCATE C
GO
