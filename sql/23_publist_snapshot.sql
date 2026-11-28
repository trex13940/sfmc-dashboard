SELECT
    CONVERT(char(7), CAST(TODATETIMEOFFSET(GETDATE(), '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS AsOf,
    g.ListName AS ListName,
    g.Status AS Status,
    g.Contract AS Contract,
    COUNT(*) AS Subscribers
FROM (
    SELECT l.ListName AS ListName, ls.Status AS Status, CASE WHEN k.ContactId IS NULL THEN 'No' ELSE 'Yes' END AS Contract
    FROM _ListSubscribers ls
    JOIN _List l ON l.ListID = ls.ListID
    LEFT JOIN (SELECT DISTINCT Contact__c AS ContactId FROM Contract_Salesforce_1 WHERE Status__c IN ('Active', 'Future')) k ON k.ContactId = ls.SubscriberKey
    WHERE l.ListType IN ('Public', 'Private') AND l.ListName <> 'All Subscribers' AND ls.SubscriberKey NOT LIKE '00QP%'
    UNION ALL
    SELECT 'All Subscribers' AS ListName, s.Status AS Status, CASE WHEN k.ContactId IS NULL THEN 'No' ELSE 'Yes' END AS Contract
    FROM _Subscribers s
    LEFT JOIN (SELECT DISTINCT Contact__c AS ContactId FROM Contract_Salesforce_1 WHERE Status__c IN ('Active', 'Future')) k ON k.ContactId = s.SubscriberKey
    WHERE s.SubscriberKey NOT LIKE '00QP%'
) g
GROUP BY g.ListName, g.Status, g.Contract
