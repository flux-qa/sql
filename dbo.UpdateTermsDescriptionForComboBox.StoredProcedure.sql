USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateTermsDescriptionForComboBox]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[UpdateTermsDescriptionForComboBox]
as


Update Terms set descriptionForComboBox = 
Concat(RTRIM(T.description), ' (',  CONVERT(varchar, Format(isnull(z.noTerms,0),'###,###,###')) , ')' ) 

    from Terms T left outer join 
    (select whseTerms_RID, count(*) as noTerms  from CustomerRelations group by whseTerms_RID) as Z
    on T.id = Z.whseTerms_RID
GO
