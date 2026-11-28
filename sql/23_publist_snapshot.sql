SELECT
    CONVERT(char(7), CAST(TODATETIMEOFFSET(GETDATE(), '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS AsOf,
    g.ListName AS ListName,
    g.Status AS Status,
    g.Contract AS Contract,
    COUNT(*) AS Subscribers
FROM (
    SELECT 'Information' AS ListName, CASE WHEN s.SubscriberKey IS NULL AND d.Status = 'Active' THEN 'Not a subscriber' ELSE ISNULL(d.Status, 'Unknown') END AS Status, CASE WHEN k.ContactId IS NULL THEN 'No' ELSE 'Yes' END AS Contract
    FROM (SELECT [Subscriber Key] AS SubscriberKey, MAX([Status]) AS Status FROM List_Info WHERE [Subscriber Key] IS NOT NULL AND [Subscriber Key] NOT LIKE '00QP%' GROUP BY [Subscriber Key]) d
    LEFT JOIN _Subscribers s ON s.SubscriberKey = d.SubscriberKey
    LEFT JOIN (SELECT DISTINCT Contact__c AS ContactId FROM Contract_Salesforce_1 WHERE Status__c IN ('Active', 'Future')) k ON k.ContactId = d.SubscriberKey
    UNION ALL
    SELECT 'Newsletter' AS ListName, CASE WHEN s.SubscriberKey IS NULL AND d.Status = 'Active' THEN 'Not a subscriber' ELSE ISNULL(d.Status, 'Unknown') END AS Status, CASE WHEN k.ContactId IS NULL THEN 'No' ELSE 'Yes' END AS Contract
    FROM (SELECT [Subscriber Key] AS SubscriberKey, MAX([Status]) AS Status FROM List_Newsletter WHERE [Subscriber Key] IS NOT NULL AND [Subscriber Key] NOT LIKE '00QP%' GROUP BY [Subscriber Key]) d
    LEFT JOIN _Subscribers s ON s.SubscriberKey = d.SubscriberKey
    LEFT JOIN (SELECT DISTINCT Contact__c AS ContactId FROM Contract_Salesforce_1 WHERE Status__c IN ('Active', 'Future')) k ON k.ContactId = d.SubscriberKey
    UNION ALL
    SELECT 'Promo' AS ListName, CASE WHEN s.SubscriberKey IS NULL AND d.Status = 'Active' THEN 'Not a subscriber' ELSE ISNULL(d.Status, 'Unknown') END AS Status, CASE WHEN k.ContactId IS NULL THEN 'No' ELSE 'Yes' END AS Contract
    FROM (SELECT [Subscriber Key] AS SubscriberKey, MAX([Status]) AS Status FROM List_Promo WHERE [Subscriber Key] IS NOT NULL AND [Subscriber Key] NOT LIKE '00QP%' GROUP BY [Subscriber Key]) d
    LEFT JOIN _Subscribers s ON s.SubscriberKey = d.SubscriberKey
    LEFT JOIN (SELECT DISTINCT Contact__c AS ContactId FROM Contract_Salesforce_1 WHERE Status__c IN ('Active', 'Future')) k ON k.ContactId = d.SubscriberKey
    UNION ALL
    SELECT 'Survey' AS ListName, CASE WHEN s.SubscriberKey IS NULL AND d.Status = 'Active' THEN 'Not a subscriber' ELSE ISNULL(d.Status, 'Unknown') END AS Status, CASE WHEN k.ContactId IS NULL THEN 'No' ELSE 'Yes' END AS Contract
    FROM (SELECT [Subscriber Key] AS SubscriberKey, MAX([Status]) AS Status FROM List_Survey WHERE [Subscriber Key] IS NOT NULL AND [Subscriber Key] NOT LIKE '00QP%' GROUP BY [Subscriber Key]) d
    LEFT JOIN _Subscribers s ON s.SubscriberKey = d.SubscriberKey
    LEFT JOIN (SELECT DISTINCT Contact__c AS ContactId FROM Contract_Salesforce_1 WHERE Status__c IN ('Active', 'Future')) k ON k.ContactId = d.SubscriberKey
    UNION ALL
    SELECT 'All Subscribers' AS ListName, s.Status AS Status, CASE WHEN k.ContactId IS NULL THEN 'No' ELSE 'Yes' END AS Contract
    FROM _Subscribers s
    LEFT JOIN (SELECT DISTINCT Contact__c AS ContactId FROM Contract_Salesforce_1 WHERE Status__c IN ('Active', 'Future')) k ON k.ContactId = s.SubscriberKey
    WHERE s.SubscriberKey NOT LIKE '00QP%'
) g
GROUP BY g.ListName, g.Status, g.Contract
