SELECT
    z.LeadId AS LeadId,
    ISNULL(z.OJourney, '(no email)') AS JourneyName,
    CASE WHEN z.OJourney IS NULL THEN 'N/A' ELSE LEFT(z.OJourney, 3) END AS Category,
    CONVERT(char(7), CAST(TODATETIMEOFFSET(ISNULL(z.OSend, z.CreatedDate), '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS SendMonth,
    CONVERT(char(10), CAST(TODATETIMEOFFSET(ISNULL(z.OSend, z.CreatedDate), '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS SendDate,
    CONVERT(char(10), CAST(TODATETIMEOFFSET(z.CreatedDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS LeadCreatedDate,
    z.Status AS LeadStatus,
    CASE WHEN z.Status = 'Signed' THEN 1 ELSE 0 END AS IsConverted,
    CASE WHEN z.OSend IS NULL THEN 0 ELSE ABS(DATEDIFF(day, CAST(CAST(TODATETIMEOFFSET(z.OSend, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2) AS date), CAST(CAST(TODATETIMEOFFSET(z.CreatedDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2) AS date))) END AS DaysToLead,
    CASE WHEN o.SubscriberID IS NOT NULL THEN 1 ELSE 0 END AS Opened,
    CASE WHEN c.SubscriberID IS NOT NULL THEN 1 ELSE 0 END AS Clicked,
    ISNULL(z.OProd, 'N/A') AS Product,
    ISNULL(z.OGroup, z.AnyGroup) AS LeadProduct,
    ojb.EmailName AS EmailName,
    ISNULL(z.OKind, 'N') AS OriginKind,
    CASE WHEN z.Status = 'Signed' THEN z.CJourney END AS ConvJourney,
    CASE WHEN z.Status = 'Signed' THEN cjb.EmailName END AS ConvEmailName,
    CASE WHEN z.Status = 'Signed' AND z.CSend IS NOT NULL THEN CONVERT(char(7), CAST(TODATETIMEOFFSET(z.CSend, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) END AS ConvSendMonth
FROM (SELECT y.LeadId AS LeadId, MAX(y.CreatedDate) AS CreatedDate, MAX(y.Status) AS Status, MAX(y.PageOrigin) AS PageOrigin, MAX(y.LeadGroup) AS AnyGroup,
           MAX(y.SubFound) AS SubFound, MAX(y.SendsCand) AS SendsCand, MAX(y.SendsProd) AS SendsProd, MAX(y.SendsKind) AS SendsKind,
           MAX(CASE WHEN y.rnO = 1 AND y.Kind IS NOT NULL THEN y.JourneyName END) AS OJourney,
           MAX(CASE WHEN y.rnO = 1 AND y.Kind IS NOT NULL THEN y.JProd END) AS OProd,
           MAX(CASE WHEN y.rnO = 1 AND y.Kind IS NOT NULL THEN y.Kind END) AS OKind,
           MAX(CASE WHEN y.rnO = 1 AND y.Kind IS NOT NULL THEN y.EventDate END) AS OSend,
           MAX(CASE WHEN y.rnO = 1 AND y.Kind IS NOT NULL THEN y.LeadGroup END) AS OGroup,
           MAX(CASE WHEN y.rnO = 1 AND y.Kind IS NOT NULL THEN y.SendSub END) AS OSub,
           MAX(CASE WHEN y.rnO = 1 AND y.Kind IS NOT NULL THEN y.JobID END) AS OJob,
           MAX(CASE WHEN y.rnO = 1 AND y.Kind IS NOT NULL THEN y.ListID END) AS OList,
           MAX(CASE WHEN y.rnO = 1 AND y.Kind IS NOT NULL THEN y.BatchID END) AS OBatch,
           MAX(CASE WHEN y.rnC = 1 AND y.Kind IS NOT NULL THEN y.JourneyName END) AS CJourney,
           MAX(CASE WHEN y.rnC = 1 AND y.Kind IS NOT NULL THEN y.EventDate END) AS CSend,
           MAX(CASE WHEN y.rnC = 1 AND y.Kind IS NOT NULL THEN y.JobID END) AS CJob
    FROM (SELECT x.*,
           ROW_NUMBER() OVER (PARTITION BY x.LeadId ORDER BY CASE WHEN x.Kind = 'M' THEN 0 WHEN x.Kind = 'T' THEN 1 ELSE 2 END,
                                                            CASE WHEN x.Kind = 'M' THEN x.EventDate END DESC,
                                                            CASE WHEN x.Kind = 'T' THEN x.EventDate END ASC) AS rnO,
           ROW_NUMBER() OVER (PARTITION BY x.LeadId ORDER BY CASE WHEN x.Kind IS NULL THEN 1 ELSE 0 END, x.EventDate DESC) AS rnC,
           SUM(x.Cand) OVER (PARTITION BY x.LeadId) AS SendsCand,
           SUM(x.ProdOk) OVER (PARTITION BY x.LeadId) AS SendsProd,
           SUM(CASE WHEN x.Kind IS NULL THEN 0 ELSE 1 END) OVER (PARTITION BY x.LeadId) AS SendsKind
    FROM (SELECT l.Id AS LeadId, l.Email AS Email, l.Status AS Status, l.CreatedDate AS CreatedDate, l.Page_Origin__c AS PageOrigin,
               ISNULL(lm.ProductGroup, 'OTHER') AS LeadGroup,
               CASE WHEN sub.SubscriberID IS NULL THEN 0 ELSE 1 END AS SubFound,
               CASE WHEN j.JourneyName IS NULL THEN 0 ELSE 1 END AS Cand,
               CASE WHEN j.JourneyName IS NOT NULL AND (j.Prod = 'ALL' OR j.JGroup = ISNULL(lm.ProductGroup, 'OTHER')) THEN 1 ELSE 0 END AS ProdOk,
               CASE WHEN j.JourneyName IS NULL THEN NULL
                    WHEN NOT (j.Prod = 'ALL' OR j.JGroup = ISNULL(lm.ProductGroup, 'OTHER')) THEN NULL
                    WHEN (j.JourneyName LIKE 'MKT[_]XSELL[_]%' OR j.JourneyName LIKE 'MKT[_]PROMO[_]%' OR j.JourneyName LIKE 'MKT[_]NEWS[_]%' OR j.JourneyName LIKE 'OCX[_]XSELL[_]%') AND j.EventDate <= l.CreatedDate THEN 'M'
                    WHEN (j.JourneyName LIKE 'OCL[_]%' OR j.JourneyName LIKE 'ODO[_]%' OR j.JourneyName LIKE 'ODD[_]OFF[_]%') AND j.EventDate >= DATEADD(hour, -1, l.CreatedDate) THEN 'T'
                    ELSE NULL END AS Kind,
               j.EventDate AS EventDate, j.JobID AS JobID, j.ListID AS ListID, j.BatchID AS BatchID, j.SubscriberID AS SendSub,
               j.JourneyName AS JourneyName, j.Prod AS JProd
        FROM (SELECT Id, Email, Status, CreatedDate, Page_Origin__c
              FROM Lead_Salesforce_1
              WHERE CreatedDate >= '20260531 16:00:00' AND CreatedDate < '20261201 00:00:00') l
        LEFT JOIN DASH_Product_Map lm ON lm.Source = 'LEAD' AND UPPER(l.Page_Origin__c) LIKE lm.Value
        LEFT JOIN _Subscribers sub ON sub.EmailAddress = l.Email
        LEFT JOIN (SELECT s.SubscriberID AS SubscriberID, s.EventDate AS EventDate, s.JobID AS JobID, s.ListID AS ListID, s.BatchID AS BatchID,
                          j0.JourneyName AS JourneyName, j0.Prod AS Prod, j0.JGroup AS JGroup
                   FROM _Sent s
                   JOIN _JourneyActivity ja ON ja.JourneyActivityObjectID = s.TriggererSendDefinitionObjectID
                   JOIN (SELECT e.VersionID AS VersionID, e.JourneyName AS JourneyName, e.Prod AS Prod, pm.ProductGroup AS JGroup
        FROM (SELECT d2.VersionID AS VersionID, d2.JourneyName AS JourneyName,
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
        WHERE d2.p3 > d2.p2) e
        LEFT JOIN DASH_Product_Map pm ON pm.Source = 'EMAIL'
                                     AND UPPER(e.Prod + '|' + e.JourneyName) LIKE pm.Value
                                     AND LEN(pm.Value) = (SELECT MAX(LEN(p2.Value)) FROM DASH_Product_Map p2
                                                          WHERE p2.Source = 'EMAIL' AND UPPER(e.Prod + '|' + e.JourneyName) LIKE p2.Value)) j0 ON j0.VersionID = ja.VersionID
                   WHERE s.EventDate >= '20260430 00:00:00') j
               ON j.SubscriberID = sub.SubscriberID
              AND j.EventDate > DATEADD(day, -30, l.CreatedDate)
              AND j.EventDate <= DATEADD(day, 30, l.CreatedDate)) x) y
    GROUP BY y.LeadId) z
LEFT JOIN _Open o ON o.JobID = z.OJob AND o.ListID = z.OList AND o.BatchID = z.OBatch AND o.SubscriberID = z.OSub AND o.IsUnique = 1
LEFT JOIN _Click c ON c.JobID = z.OJob AND c.ListID = z.OList AND c.BatchID = z.OBatch AND c.SubscriberID = z.OSub AND c.IsUnique = 1
LEFT JOIN _Job ojb ON ojb.JobID = z.OJob
LEFT JOIN _Job cjb ON cjb.JobID = z.CJob
