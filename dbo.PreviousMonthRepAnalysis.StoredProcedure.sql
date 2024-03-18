USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[PreviousMonthRepAnalysis]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PreviousMonthRepAnalysis]

    @currentDate            date,
    @rep                    varchar(5) = 'SK'

as
declare 

    @lastMonthFrom          date,
    @lastMonthThru          date,
    @lastYearLastMonthFrom  date,
    @lastYearLastMonthThru  date,
    @lastYearNextMonthFrom  date,
    @lastYearNextMonthThru  date,
    @yearStart              date
    
set @currentDate = getDate()
set @lastMonthThru = EOMONTH(@currentDate, -1)
set @lastMonthFrom = dateAdd(dd, 1, EOMONTH(@lastMonthThru, -1))

set @lastYearLastMonthThru = EOMONTH(@currentDate, -13)
set @lastYearLastMonthFrom = dateAdd(dd, 1, EOMONTH(@lastYearLastMonthThru, -1)) 

set @lastYearNextMonthThru = EOMONTH(@currentDate, -12)
set @lastYearNextMonthFrom = dateAdd(dd, 1, EOMONTH(@lastYearNextMonthThru, -1))
   
set @yearStart = dateAdd(mm, - (month(@lastMonthFrom) - 1), @lastMonthFrom)   
--select @lastMonthFrom, @lastMonthThru, @lastYearLastMonthFrom, @lastYearLastMonthThru, @yearStart, @lastYearNextMonthFrom, @lastYearNextMonthThru 


select row_number() over (order by C.ID) as ID, 1 as BASVERSION, getdate() as BASTIMESTAMP,
left(C.fieldRep,2) as rep, outsidefieldRep as outsideRep, C.name, C.city, lastYear, lastMonth, lastMonth - lastYear as growth,
    case when lastYear = 0 then 0 else round(100.0 * (lastMonth - lastYear) / lastYear,0) end as growthPct, nextMonth, ytd
    from Customers C inner join (select I.ob_Customer_RID , 
        round(sum(case when I.dateShipped between @lastYearLastMonthFrom and @lastYearLastMonthThru then I.subTotal else 0 end),0) as lastYear,
        round(sum(case when I.dateShipped between @lastYearNextMonthFrom and @lastYearNextMonthThru then I.subTotal else 0 end),0) as nextMonth,
        round(sum(case when I.dateShipped between @lastMonthFrom and @lastMonthThru then I.subTotal else 0 end),0) as lastMonth,
        round(sum(case when I.dateShipped between @yearStart and @lastMonthThru then I.subTotal else 0 end),0) as ytd
        from Invoices I where I.dateShipped >= @lastYearLastMonthFrom 
        group by I.ob_Customer_RID) as Z on C.ID = Z.ob_Customer_RID
        WHERE (@rep = 'bruce' OR @rep = 'JK' OR left(c.fieldRep,2) = @rep OR C.outsideFieldRep = @rep)
        order by left(C.fieldRep,2), name, city
GO
