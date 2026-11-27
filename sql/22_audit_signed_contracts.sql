SELECT
    d.LeadId AS LeadId,
    d.LeadProduct AS LeadProduct,
    d.Product AS JourneyProduct,
    d.JourneyName AS JourneyName,
    d.EmailName AS EmailName,
    COUNT(k.Status__c) AS ActiveOrFutureContracts,
    SUM(CASE WHEN cm.ProductGroup = d.LeadProduct THEN 1 ELSE 0 END) AS ContractsOfTheLeadGroup,
    CASE WHEN COUNT(k.Status__c) = 0 THEN 'No active or future contract for this email'
         WHEN SUM(CASE WHEN cm.ProductGroup = d.LeadProduct THEN 1 ELSE 0 END) > 0 THEN 'Contract in the same product group'
         ELSE 'Contract(s) in another product group (or Product2__c not mapped)' END AS Check1
FROM DASH_Conversions d
JOIN Lead_Salesforce_1 l ON l.Id = d.LeadId
LEFT JOIN Contact_Salesforce_1 c ON c.Email = l.Email
LEFT JOIN Contract_Salesforce_1 k ON k.Contact__c = c.Id AND k.Status__c IN ('Active', 'Future')
LEFT JOIN DASH_Product_Map cm ON cm.Source = 'CONTRACT' AND UPPER(k.Product2__c) LIKE cm.Value
WHERE d.IsConverted = 1
GROUP BY d.LeadId, d.LeadProduct, d.Product, d.JourneyName, d.EmailName
