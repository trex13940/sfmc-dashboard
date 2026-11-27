SELECT
    y.LeadId AS LeadId,
    CONVERT(char(10), CAST(TODATETIMEOFFSET(y.CreatedDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS CreatedDate,
    CONVERT(char(7), CAST(TODATETIMEOFFSET(y.CreatedDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS Month,
    y.Status AS Status,
    y.PageOrigin AS PageOrigin,
    y.LeadGroup AS LeadGroup,
    CASE WHEN y.StatusEligible = 0 THEN '0 Lead status is not tracked'
         WHEN y.HasEmail = 0 THEN '1 No email on the lead'
         WHEN y.SubFound = 0 THEN '2 Email not found in _Subscribers'
         WHEN y.SendsAll = 0 THEN '3 No email sent in the 30 days before creation'
         WHEN y.SendsJourney = 0 THEN '4 Emails sent, but none from a journey'
         WHEN y.SendsEligible = 0 THEN '5 Journey emails, but none from a tracked journey family'
         WHEN y.SendsStatusOk = 0 THEN '6 Lead status does not match the journey (Incomplete, Offer Created)'
         WHEN y.SendsProductOk = 0 THEN '7 Product of the lead and of the journey do not match'
         ELSE '8 Attributed' END AS Reason,
    y.SendsAll AS SendsAll,
    y.SendsJourney AS SendsJourney,
    y.SendsEligible AS SendsEligible,
    y.SendsStatusOk AS SendsStatusOk,
    y.SendsProductOk AS SendsProductOk,
    y.JourneyName AS BestJourney,
    y.JProd AS BestJourneyProduct,
    y.JGroup AS BestJourneyGroup,
    jb.EmailName AS BestEmail,
    CONVERT(char(10), CAST(TODATETIMEOFFSET(y.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS BestSendDate
FROM (
    SELECT x.*,
           ROW_NUMBER() OVER (PARTITION BY x.LeadId ORDER BY x.AllOk DESC, x.EligOk DESC, x.JourneyOk DESC, x.EventDate DESC) AS rn,
           SUM(x.SendOk) OVER (PARTITION BY x.LeadId) AS SendsAll,
           SUM(x.JourneyOk) OVER (PARTITION BY x.LeadId) AS SendsJourney,
           SUM(x.EligOk) OVER (PARTITION BY x.LeadId) AS SendsEligible,
           SUM(CASE WHEN x.EligOk = 1 AND x.StatusOk = 1 THEN 1 ELSE 0 END) OVER (PARTITION BY x.LeadId) AS SendsStatusOk,
           SUM(x.AllOk) OVER (PARTITION BY x.LeadId) AS SendsProductOk
    FROM (
        SELECT l.Id AS LeadId, l.CreatedDate AS CreatedDate, l.Status AS Status, l.Page_Origin__c AS PageOrigin,
               ISNULL(lm.ProductGroup, 'OTHER') AS LeadGroup,
               CASE WHEN l.Status IN ('Incomplete', 'Viewed Premium', 'Offer Incomplete', 'Offer Viewed', 'Offer Created', 'Signing', 'Signed') THEN 1 ELSE 0 END AS StatusEligible,
               CASE WHEN l.Email IS NULL OR l.Email = '' THEN 0 ELSE 1 END AS HasEmail,
               CASE WHEN sub.SubscriberID IS NULL THEN 0 ELSE 1 END AS SubFound,
               CASE WHEN s.SubscriberID IS NULL THEN 0 ELSE 1 END AS SendOk,
               CASE WHEN ja.VersionID IS NULL THEN 0 ELSE 1 END AS JourneyOk,
               CASE WHEN j.JourneyName IS NULL THEN 0 ELSE 1 END AS EligOk,
               CASE WHEN (l.Status NOT IN ('Incomplete', 'Offer Created')
               OR (l.Status = 'Incomplete' AND j.JourneyName LIKE 'ODO[_]BANK[_]CAR[_]DropOut%')
               OR (l.Status = 'Offer Created' AND j.JourneyName LIKE 'ODD[_]OFF[_]%')) THEN 1 ELSE 0 END AS StatusOk,
               CASE WHEN j.JourneyName IS NOT NULL AND l.Status IN ('Incomplete', 'Viewed Premium', 'Offer Incomplete', 'Offer Viewed', 'Offer Created', 'Signing', 'Signed') AND (l.Status NOT IN ('Incomplete', 'Offer Created')
               OR (l.Status = 'Incomplete' AND j.JourneyName LIKE 'ODO[_]BANK[_]CAR[_]DropOut%')
               OR (l.Status = 'Offer Created' AND j.JourneyName LIKE 'ODD[_]OFF[_]%'))
                         AND (j.Prod = 'ALL' OR j.JGroup = ISNULL(lm.ProductGroup, 'OTHER')) THEN 1 ELSE 0 END AS AllOk,
               s.EventDate AS EventDate, s.JobID AS JobID, j.JourneyName AS JourneyName, j.Prod AS JProd, j.JGroup AS JGroup
        FROM (SELECT Id, Email, Status, CreatedDate, Page_Origin__c
              FROM Lead_Salesforce_1
              WHERE CreatedDate >= '20260831 16:00:00' AND CreatedDate < '20260930 16:00:00') l
        LEFT JOIN DASH_Product_Map lm ON lm.Source = 'LEAD' AND UPPER(l.Page_Origin__c) LIKE lm.Value
        LEFT JOIN _Subscribers sub ON sub.EmailAddress = l.Email
        LEFT JOIN _Sent s ON s.SubscriberID = sub.SubscriberID
                         AND s.EventDate >= '20260731 00:00:00'
                         AND s.EventDate <= l.CreatedDate
                         AND s.EventDate > DATEADD(day, -30, l.CreatedDate)
        LEFT JOIN _JourneyActivity ja ON ja.JourneyActivityObjectID = s.TriggererSendDefinitionObjectID
        LEFT JOIN (SELECT e.VersionID AS VersionID, e.JourneyName AS JourneyName, e.Prod AS Prod, pm.ProductGroup AS JGroup
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
                                                          WHERE p2.Source = 'EMAIL' AND UPPER(e.Prod + '|' + e.JourneyName) LIKE p2.Value)) j ON j.VersionID = ja.VersionID
    ) x
) y
LEFT JOIN _Job jb ON jb.JobID = y.JobID
WHERE y.rn = 1
