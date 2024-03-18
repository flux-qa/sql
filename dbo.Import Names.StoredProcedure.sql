USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[Import Names]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Import Names]   
as


-- 1st fix the billtos in the names table
update alc.dbo.names set billto = 0

update alc.dbo.Names set billto = M.billToNumber
from alc.dbo.names N inner join (
select N.custno, M.custno as billToNumber
from alc.dbo.names N inner join alc.dbo.names M on N.oldbilltoCode = M.oldCustNo
where N.oldBillToCode <> 'SAME' and N.oldBillToCode <> '')
 as M on N.custno = M.custno
 
update alc.dbo.names set billto = custno where 
oldBillToCode = 'SAME' or oldBillToCode = ''

update alc.dbo.names set billto = custno where billto = 0


truncate table CUSTOMERS

INSERT INTO [CUSTOMERS]([ID], [BASVERSION], [BASTIMESTAMP], 
[state], [name], [zip], [balance], [fax], 
[creditLimit], [active], [custno], [city], [add2], 
[oldCustNo], [add1],[phone], [email], [pctToOverShip], [fieldRep],
 whseTerms_RID, whseTerms_REN, handlingMultiplier, minShippableSaleAmount, oldBillToCode,
 resaleCertificate, altDeliveryLocation ) 

select custno, 1, getDate(), state, name, zip, balance, 
fax, creditLimit, activeFlag,
custno, city, add2, left(oldCustNo,4), add1, phone, email, pctToOverShip, fieldRep, 
T.ID, 'Terms', 1, 2000, oldBillToCode, resaleNo, 0
    
from ALC.dbo.Names N left outer join TERMS T on N.whseTerms = T.termsCode



-- NOW IMPORT THE CUSTOMER RELATIONS
truncate table CUSTOMERRELATIONS

;
with w as (select distinct
 
M.custno, M.name, M.add1, M.add2, M.city, M.state, M.zip, M.phone, M.fax, M.email, 
M.resaleNo, 'Bill To' as relationType, '' as blank, M.oldCustno, 
'Hold Shipments' as creditLimitRule, M.whseTerms, M.directTerms , 0 as emailInvoices, 0 as emailStatements, M.creditlimit
from ALC.dbo.Names N inner join ALC.dbo.names M on N.billTo = M.custno
)

-- 1st insert customers who have a BillTo WHICH SHOULD BE ALL NOW
Insert into CUSTOMERRELATIONS (ID, BASVERSION, BASTIMESTAMP,
custno, name, add1, add2, city, state, zip, phone, fax, email, 
resaleCertificate, relationType, oldCustNo, oldBillToCode, creditLimitRule, 
oldWhseTermsCode, oldDirectTermsCode, emailInvoices, emailStatements,
creditLimit)



select  custno, 1, getDate(), 
custno, name, add1, add2, city, state, zip, phone, fax, email, 
resaleNo, relationType, blank, oldCustno, 
creditLimitRule, whseTerms, directTerms , emailInvoices, emailStatements, creditlimit
from W

/*
-- 2nd insert customers who have SAME or BLANK billTo
Insert into CUSTOMERRELATIONS (ID, BASVERSION, BASTIMESTAMP,
custno, name, add1, add2, city, state, zip, phone, fax, email, 
resaleCertificate, relationType, oldCustNo, oldBillToCode, creditLimitRule, oldWhseTermsCode, oldDirectTermsCode, preferred)

select  row_number() over (order by custno), 1, getDate(), 
custno, name, add1, add2, city, state, zip, phone, fax, email, 
resaleNo, 'Bill To', oldCustno, oldCustno, 
'Hold Shipments', whseTerms, directTerms , 1
from ALC.dbo.Names 
where (OldBillToCode = 'SAME' or oldBillToCode = '' or oldBillToCode = oldCustNo)
and oldCustNo not in (select oldbilltocode from CustomerRelations)
*/
/*
-- DELETE DUPLICATE OldBillToCodes
delete from customerRelations where ID in (select c2.id
    from customerRelations C1
    inner join CustomerRelations C2 on C1.oldbilltoCode = C2.oldbilltocode
    and C1.ID > C2.ID)
*/
-- CREATE THE MANY TO MANY RELATIONSHIP
delete from CUSTOMERRELATIONS_REF

-- 1st the Customers with the same bill To
INSERT INTO [dbo].[CUSTOMERRELATIONS_REF]( [ID], [FIELD_NAME], [REN], [RID], [RMA]) 

select  R.ID, 'pm_Customers', 'Customers', C.ID, 'pm_CustomerRelations'
from CUSTOMERS C inner join CUSTOMERRELATIONS R on  C.ID = R.custno
where C.oldBillToCode = 'SAME' or C.oldBillToCode = '' or C.oldBillToCode = C.oldCustno

-- Next Customers with Diff BillTos
INSERT INTO [dbo].[CUSTOMERRELATIONS_REF]( [ID], [FIELD_NAME], [REN], [RID], [RMA]) 

select  R.ID, 'pm_Customers', 'Customers', C.ID, 'pm_CustomerRelations'
from CUSTOMERS C inner join CUSTOMERRELATIONS R on  C.oldBillToCode = R.oldBillToCode
where C.oldBillToCode <> 'SAME' AND C.oldBillToCode <> '' and C.oldBillToCode <> C.oldCustno
and R.oldCustno <> R.oldBillToCode



update CUSTOMERS set noBillToRecords = 0

update CUSTOMERS
set noBillToRecords = noBillTos
from CUSTOMERS C inner join (
select RID, count(*) as noBillTos from CUSTOMERRELATIONS_REF
group by RID) as Z on C.ID = Z.RID

-- NOW UPDATE THE SECTOR RELATIONSHIPS
update CUSTOMERS set ps_Sector_RID = null

update CUSTOMERS set ps_Sector_RID = BS.ID, ps_Sector_REN = 'Sectors'

    from SectorImport S inner join CUSTOMERS C on S.state = C.state and S.city = C.city
    inner join SECTORS BS on BS.name = S.sector


Update CUSTOMERS set ps_Sector_RID = 0, ps_Sector_REN = 'Sectors'
where ps_sector_RID is null

Update CUSTOMERRELATIONS
    set whseTerms_REN = 'Terms', whseTerms_RID = T.ID
from CUSTOMERRELATIONS C inner join TERMS T on C.oldWhseTermsCode = T.termsCode

-- FIX the NO SECTOR list that JOSH gave me on 8/28/17
exec UpdateCustomerSectorsFromListFromJosh

Update Customers set fieldRep = rtrim(left(B.fieldRep,3)), 
    outsideFieldRep = rtrim(left(B.outsideFieldRep,3))
    from Customers C inner join customersWithBothReps B on C.oldCustNo = B.code
GO
