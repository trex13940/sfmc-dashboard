SELECT
    CONVERT(char(7), CAST(TODATETIMEOFFSET(GETDATE(), '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS AsOf,
    g.ListName AS ListName,
    g.Status AS Status,
    g.Contract AS Contract,
    COUNT(*) AS Subscribers
FROM (
    SELECT 'Information' AS ListName, ISNULL(s.Status, 'Not in All Subscribers') AS Status, CASE WHEN k.ContactId IS NULL THEN 'No' ELSE 'Yes' END AS Contract
    FROM (SELECT DISTINCT [Subscriber Key] AS SubscriberKey FROM List_Info WHERE [Subscriber Key] IS NOT NULL AND [Subscriber Key] NOT LIKE '00QP%') d
    LEFT JOIN _Subscribers s ON s.SubscriberKey = d.SubscriberKey
    LEFT JOIN (SELECT DISTINCT Contact__c AS ContactId FROM Contract_Salesforce_1 WHERE Status__c IN ('Active', 'Future')) k ON k.ContactId = d.SubscriberKey
    UNION ALL
    SELECT 'Newsletter' AS ListName, ISNULL(s.Status, 'Not in All Subscribers') AS Status, CASE WHEN k.ContactId IS NULL THEN 'No' ELSE 'Yes' END AS Contract
    FROM (SELECT DISTINCT [Subscriber Key] AS SubscriberKey FROM List_Newsletter WHERE [Subscriber Key] IS NOT NULL AND [Subscriber Key] NOT LIKE '00QP%') d
    LEFT JOIN _Subscribers s ON s.SubscriberKey = d.SubscriberKey
    LEFT JOIN (SELECT DISTINCT Contact__c AS ContactId FROM Contract_Salesforce_1 WHERE Status__c IN ('Active', 'Future')) k ON k.ContactId = d.SubscriberKey
    UNION ALL
    SELECT 'Promo' AS ListName, ISNULL(s.Status, 'Not in All Subscribers') AS Status, CASE WHEN k.ContactId IS NULL THEN 'No' ELSE 'Yes' END AS Contract
    FROM (SELECT DISTINCT [Subscriber Key] AS SubscriberKey FROM List_Promo WHERE [Subscriber Key] IS NOT NULL AND [Subscriber Key] NOT LIKE '00QP%') d
    LEFT JOIN _Subscribers s ON s.SubscriberKey = d.SubscriberKey
    LEFT JOIN (SELECT DISTINCT Contact__c AS ContactId FROM Contract_Salesforce_1 WHERE Status__c IN ('Active', 'Future')) k ON k.ContactId = d.SubscriberKey
    UNION ALL
    SELECT 'Survey' AS ListName, ISNULL(s.Status, 'Not in All Subscribers') AS Status, CASE WHEN k.ContactId IS NULL THEN 'No' ELSE 'Yes' END AS Contract
    FROM (SELECT DISTINCT [Subscriber Key] AS SubscriberKey FROM List_Survey WHERE [Subscriber Key] IS NOT NULL AND [Subscriber Key] NOT LIKE '00QP%') d
    LEFT JOIN _Subscribers s ON s.SubscriberKey = d.SubscriberKey
    LEFT JOIN (SELECT DISTINCT Contact__c AS ContactId FROM Contract_Salesforce_1 WHERE Status__c IN ('Active', 'Future')) k ON k.ContactId = d.SubscriberKey
    UNION ALL
    SELECT 'All Subscribers' AS ListName, s.Status AS Status, CASE WHEN k.ContactId IS NULL THEN 'No' ELSE 'Yes' END AS Contract
    FROM _Subscribers s
    LEFT JOIN (SELECT DISTINCT Contact__c AS ContactId FROM Contract_Salesforce_1 WHERE Status__c IN ('Active', 'Future')) k ON k.ContactId = s.SubscriberKey
    WHERE s.SubscriberKey NOT LIKE '00QP%'
) g
GROUP BY g.ListName, g.Status, g.Contract
