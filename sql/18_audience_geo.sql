SELECT
    g.PostalCode AS PostalCode,
    COUNT(*) AS Contacts,
    SUM(CASE WHEN g.HasContract = 1 THEN 1 ELSE 0 END) AS WithContract,
    CONVERT(char(10), CAST(TODATETIMEOFFSET(GETDATE(), '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS AsOf
FROM (SELECT z.Id AS Id,
             z.HasContract AS HasContract,
             CASE WHEN z.P1 LIKE '[0-9][0-9][0-9][0-9]' THEN CASE WHEN CAST(z.P1 AS int) BETWEEN 1000 AND 9999 THEN z.P1 ELSE 'N/A' END ELSE 'N/A' END AS PostalCode
      FROM (SELECT c.Id AS Id,
                   LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(UPPER(ISNULL(c.MailingPostalCode, '')), 'BE-', ''), 'B-', ''), 'BE ', ''))) AS P1,
                   CASE WHEN k.ContactId IS NULL THEN 0 ELSE 1 END AS HasContract
            FROM Contact_Salesforce_1 c
            LEFT JOIN (SELECT DISTINCT Contact__c AS ContactId FROM Contract_Salesforce_1 WHERE Status__c IN ('Active', 'Future')) k ON k.ContactId = c.Id
            WHERE c.Id NOT LIKE '00QP%') z) g
GROUP BY g.PostalCode
