USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateNextContractorInOrderLines]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateNextContractorInOrderLines]
as


-- SAVE THE NEXT CONTRACTOR IN ORDERLINES IF THERE ARE ANY CONTRACTORS NOT COMPLETE
update orderLines 
    set contractorFlag = 1,
    ps_NextContractor_REN = 'Contractors',
    ps_NextContractor_RID = C.ID

from OrderLines L inner join OrderLineServiceCharges O on L.ID = O.ob_OrderLines_RID
    inner join Contractors C on O.ps_Contractor_RID = C.ID

-- FIND THE NEXT (LOWEST) SEQUENCE NUMBER THAT IS NOT COMPLETE THAT HAS A CONTRACTOR
inner join (select ob_OrderLines_RID as orderLineID, min(sequenceNumber) as nextSequence
        from OrderLineServiceCharges
        where stopComplete = 0 and ps_Contractor_RID > 0
        group by ob_OrderLines_RID) as M on M.orderLineID = L.ID and M.nextSequence = O.sequenceNumber
        
update Orders set contractorFlag = 0 where contractorFlag = 1
     
update Orders
    set contractorFlag = 1,
    ps_NextContractor_REN = 'Contractors',
    ps_NextContractor_RID = L.ps_NextContractor_RID

from Orders O inner join OrderLines L on O.ID = L.ob_Orders_RID
where L.contractorFlag = 1
GO
