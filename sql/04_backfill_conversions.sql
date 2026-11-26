SELECT
    t.LeadId AS LeadId,
    t.JourneyName AS JourneyName,
    LEFT(t.JourneyName, 3) AS Category,
    CONVERT(char(7), CAST(TODATETIMEOFFSET(t.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS SendMonth,
    CONVERT(char(10), CAST(TODATETIMEOFFSET(t.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS SendDate,
    CONVERT(char(10), CAST(TODATETIMEOFFSET(t.LeadCreated, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS LeadCreatedDate,
    t.LeadStatus AS LeadStatus,
    CASE WHEN t.LeadStatus = 'Signed' THEN 1 ELSE 0 END AS IsConverted,
    DATEDIFF(day, CAST(CAST(TODATETIMEOFFSET(t.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2) AS date), CAST(CAST(TODATETIMEOFFSET(t.LeadCreated, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2) AS date)) AS DaysToLead,
    CASE WHEN o.SubscriberID IS NOT NULL THEN 1 ELSE 0 END AS Opened,
    CASE WHEN c.SubscriberID IS NOT NULL THEN 1 ELSE 0 END AS Clicked,
    t.Prod AS Product,
    t.LeadProd AS LeadProduct,
    jb.EmailName AS EmailName
FROM (
    SELECT x.LeadId, x.LeadStatus, x.LeadProd, x.LeadCreated, x.EventDate, x.JobID, x.ListID, x.BatchID, x.SubscriberID, x.JourneyName, x.Prod,
           ROW_NUMBER() OVER (PARTITION BY x.LeadId ORDER BY x.EventDate DESC) AS rn
    FROM (
        SELECT l.Id AS LeadId, l.Status AS LeadStatus, l.LeadProd AS LeadProd, l.CreatedDate AS LeadCreated,
               s.EventDate, s.JobID, s.ListID, s.BatchID, s.SubscriberID, j.JourneyName, j.Prod
        FROM (SELECT Id, Email, Status, CreatedDate,
                     CASE WHEN Page_Origin__c = 'PET' THEN 'PET'
                         WHEN Page_Origin__c = 'VEH_V2' THEN 'CAR'
                         WHEN Page_Origin__c = 'VEH_MO' THEN 'MOT'
                         WHEN Page_Origin__c = 'HOM' THEN 'RENTERS'
                         WHEN Page_Origin__c = 'OWNER' THEN 'OWNER'
                         WHEN Page_Origin__c = 'FEM' THEN 'FAM'
                         WHEN Page_Origin__c = 'ASS' THEN 'ASS'
                         WHEN Page_Origin__c LIKE '%ukp%' THEN 'FUN'
                         ELSE 'OTHER' END AS LeadProd
              FROM Lead_Salesforce_1
              WHERE CreatedDate >= '20260531 16:00:00' AND CreatedDate < '20261201 00:00:00'
                AND Email IS NOT NULL AND Email <> ''
                AND Status IN ('Incomplete', 'Viewed Premium', 'Offer Incomplete', 'Offer Viewed', 'Offer Created', 'Signing', 'Signed')) l
        JOIN _Subscribers sub ON sub.EmailAddress = l.Email
        JOIN _Sent s ON s.SubscriberID = sub.SubscriberID
                    AND s.EventDate >= '20260501 00:00:00'
                    AND s.EventDate <= l.CreatedDate
                    AND s.EventDate > DATEADD(day, -30, l.CreatedDate)
        JOIN _JourneyActivity ja ON ja.JourneyActivityObjectID = s.TriggererSendDefinitionObjectID
        JOIN (SELECT d2.VersionID, d2.JourneyName,
               CASE WHEN UPPER(SUBSTRING(d2.JourneyName, d2.p2 + 1, d2.p3 - d2.p2 - 1)) = 'BIKE' THEN 'BIK'
                    ELSE UPPER(SUBSTRING(d2.JourneyName, d2.p2 + 1, d2.p3 - d2.p2 - 1)) END AS Prod
        FROM (SELECT d1.VersionID, d1.JourneyName, d1.p2, CHARINDEX('_', d1.JourneyName, d1.p2 + 1) AS p3
              FROM (SELECT d0.VersionID, d0.JourneyName, CHARINDEX('_', d0.JourneyName, d0.p1 + 1) AS p2
                    FROM (SELECT VersionID, JourneyName, CHARINDEX('_', JourneyName) AS p1
                          FROM _Journey
                          WHERE (JourneyName LIKE 'MKT[_]XSELL[_]%' OR JourneyName LIKE 'MKT[_]PROMO[_]%' OR JourneyName LIKE 'MKT[_]NEWS[_]%'
                 OR JourneyName LIKE 'ODO[_]%' OR JourneyName LIKE 'OCL[_]%' OR JourneyName LIKE 'ODD[_]OFF[_]%' OR JourneyName LIKE 'OCX[_]XSELL[_]%')) d0
                    WHERE d0.p1 > 0) d1
              WHERE d1.p2 > 0) d2
        WHERE d2.p3 > d2.p2) j ON j.VersionID = ja.VersionID
        WHERE (l.Status NOT IN ('Incomplete', 'Offer Created')
               OR (l.Status = 'Incomplete' AND j.JourneyName LIKE 'ODO[_]BANK[_]CAR[_]DropOut%')
               OR (l.Status = 'Offer Created' AND j.JourneyName LIKE 'ODD[_]OFF[_]%'))
          AND (j.Prod = 'ALL'
               OR j.Prod = l.LeadProd
               OR (j.Prod = 'VEH' AND l.LeadProd IN ('CAR', 'MOT'))
               OR (j.Prod = 'HOM' AND ((l.LeadProd = 'RENTERS' AND j.JourneyName NOT LIKE '%owner%')
                                    OR (l.LeadProd = 'OWNER' AND j.JourneyName NOT LIKE '%renter%'))))
    ) x
) t
LEFT JOIN _Open o ON o.JobID=t.JobID AND o.ListID=t.ListID AND o.BatchID=t.BatchID AND o.SubscriberID=t.SubscriberID AND o.IsUnique=1
LEFT JOIN _Click c ON c.JobID=t.JobID AND c.ListID=t.ListID AND c.BatchID=t.BatchID AND c.SubscriberID=t.SubscriberID AND c.IsUnique=1
LEFT JOIN _Job jb ON jb.JobID = t.JobID
WHERE t.rn = 1
