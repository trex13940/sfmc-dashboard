SELECT
    j.JourneyName AS JourneyName,
    CONVERT(char(7), CAST(TODATETIMEOFFSET(s.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS [Month],
    jb.EmailName AS EmailName,
    COUNT(*) AS Sends,
    COUNT(b.SubscriberID) AS Bounces,
    COUNT(o.SubscriberID) AS Opens,
    COUNT(c.SubscriberID) AS UniqueClicks,
    COUNT(u.SubscriberID) AS Unsubscribes,
    COUNT(cp.SubscriberID) AS Complaints
FROM _Sent s
JOIN _JourneyActivity ja ON ja.JourneyActivityObjectID = s.TriggererSendDefinitionObjectID
JOIN _Journey j ON j.VersionID = ja.VersionID
JOIN _Job jb ON jb.JobID = s.JobID
LEFT JOIN _Bounce b ON b.JobID=s.JobID AND b.ListID=s.ListID AND b.BatchID=s.BatchID AND b.SubscriberID=s.SubscriberID AND b.IsUnique=1
LEFT JOIN _Open o ON o.JobID=s.JobID AND o.ListID=s.ListID AND o.BatchID=s.BatchID AND o.SubscriberID=s.SubscriberID AND o.IsUnique=1
LEFT JOIN _Click c ON c.JobID=s.JobID AND c.ListID=s.ListID AND c.BatchID=s.BatchID AND c.SubscriberID=s.SubscriberID AND c.IsUnique=1
LEFT JOIN _Unsubscribe u ON u.JobID=s.JobID AND u.ListID=s.ListID AND u.BatchID=s.BatchID AND u.SubscriberID=s.SubscriberID AND u.IsUnique=1
LEFT JOIN _Complaint cp ON cp.JobID=s.JobID AND cp.ListID=s.ListID AND cp.BatchID=s.BatchID AND cp.SubscriberID=s.SubscriberID AND cp.IsUnique=1
WHERE s.EventDate >= '20260531 16:00:00'
  AND s.EventDate < '20261201 00:00:00'
  AND (j.JourneyName LIKE 'MKT[_]%' OR j.JourneyName LIKE 'O__[_]%')
GROUP BY j.JourneyName, CONVERT(char(7), CAST(TODATETIMEOFFSET(s.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120), jb.EmailName
