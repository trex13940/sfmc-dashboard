SELECT
    g.PostalCode AS PostalCode,
    COUNT(*) AS Contacts,
    CONVERT(char(10), CAST(TODATETIMEOFFSET(GETDATE(), '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS AsOf
FROM (SELECT z.Id AS Id,
             CASE WHEN z.P1 LIKE '[0-9][0-9][0-9][0-9]' THEN CASE WHEN CAST(z.P1 AS int) BETWEEN 1000 AND 9999 THEN z.P1 ELSE 'N/A' END ELSE 'N/A' END AS PostalCode
      FROM (SELECT c.Id AS Id,
                   LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(UPPER(ISNULL(c.MailingPostalCode, '')), 'BE-', ''), 'B-', ''), 'BE ', ''))) AS P1
            FROM Contact_Salesforce_1 c) z) g
GROUP BY g.PostalCode
