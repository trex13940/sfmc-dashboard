SELECT
    t.LeadId                                         AS LeadId,
    t.JourneyName                                    AS JourneyName,
    LEFT(t.JourneyName, 3)                           AS Category,
    CONVERT(char(7),  CAST(TODATETIMEOFFSET(t.EventDate,   '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS SendMonth,
    CONVERT(char(10), CAST(TODATETIMEOFFSET(t.EventDate,   '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS SendDate,
    CONVERT(char(10), CAST(TODATETIMEOFFSET(t.LeadCreated, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS LeadCreatedDate,
    t.LeadStatus                                     AS LeadStatus,
    CASE WHEN t.LeadStatus = 'Signed' THEN 1 ELSE 0 END  AS IsConverted   ,
    DATEDIFF(day,
        CAST(CAST(TODATETIMEOFFSET(t.EventDate,   '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2) AS date),
        CAST(CAST(TODATETIMEOFFSET(t.LeadCreated, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2) AS date)) AS DaysToLead,
    CASE WHEN o.SubscriberID IS NOT NULL THEN 1 ELSE 0 END AS Opened,
    CASE WHEN c.SubscriberID IS NOT NULL THEN 1 ELSE 0 END AS Clicked
FROM (
    SELECT x.LeadId, x.LeadStatus, x.LeadCreated, x.EventDate, x.JobID, x.ListID, x.BatchID, x.SubscriberID, x.JourneyName,
           ROW_NUMBER() OVER (PARTITION BY x.LeadId ORDER BY x.EventDate DESC) AS rn
    FROM (
        SELECT l.Id AS LeadId, l.Status AS LeadStatus, l.CreatedDate AS LeadCreated,
               s.EventDate, s.JobID, s.ListID, s.BatchID, s.SubscriberID, j.JourneyName
        FROM (SELECT Id, Email, Status, CreatedDate
              FROM Lead_Salesforce_1
              WHERE CreatedDate >= DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 3, 0) AND CreatedDate < DATEADD(day, 1, GETDATE())
                AND Email IS NOT NULL AND Email <> '') l
        JOIN _Subscribers sub ON sub.EmailAddress = l.Email
        JOIN _Sent s ON s.SubscriberID = sub.SubscriberID
                    AND s.EventDate >= DATEADD(day, -30, DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 3, 0))
                    AND s.EventDate <= l.CreatedDate
                    AND s.EventDate >  DATEADD(day, -30, l.CreatedDate)
        JOIN _JourneyActivity ja ON ja.JourneyActivityObjectID = s.TriggererSendDefinitionObjectID
        JOIN _Journey j          ON j.VersionID = ja.VersionID
        WHERE (j.JourneyName LIKE 'MKT[_]%' OR j.JourneyName LIKE 'O__[_]%')
    ) x
) t
LEFT JOIN _Open  o ON o.JobID=t.JobID AND o.ListID=t.ListID AND o.BatchID=t.BatchID AND o.SubscriberID=t.SubscriberID AND o.IsUnique=1
LEFT JOIN _Click c ON c.JobID=t.JobID AND c.ListID=t.ListID AND c.BatchID=t.BatchID AND c.SubscriberID=t.SubscriberID AND c.IsUnique=1
WHERE t.rn = 1
