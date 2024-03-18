USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[MobileLogin]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[MobileLogin]

-- 01/26/24 -- CREATED

    @username       varchar(200),
    @accesstoken    varchar(3000)
as

        
    
    IF @accessToken <> '' Update RegularUser set accessToken = @accessToken
    where LoginName = @username

    select  id, LoginName as username, mobilePassword as password, fullname, accesstoken,
        cast(diggernumber as integer) as diggerNumber, diggeraccess, 
        cast(nodigstoday as integer) as nodigstoday, cast(diggerlastlogin as datetime) as diggerlastlogin
    from RegularUser
        where LoginName = @username
GO
