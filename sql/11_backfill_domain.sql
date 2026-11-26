SELECT
    s.Domain AS Domain,
    CONVERT(char(7), CAST(TODATETIMEOFFSET(s.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS [Month],
    COUNT(*) AS Sends,
    COUNT(b.SubscriberID) AS Bounces,
    COUNT(cp.SubscriberID) AS Complaints
FROM _Sent s
JOIN _JourneyActivity ja ON ja.JourneyActivityObjectID = s.TriggererSendDefinitionObjectID
JOIN _Journey j ON j.VersionID = ja.VersionID
LEFT JOIN _Bounce b ON b.JobID=s.JobID AND b.ListID=s.ListID AND b.BatchID=s.BatchID AND b.SubscriberID=s.SubscriberID AND b.IsUnique=1
LEFT JOIN _Complaint cp ON cp.JobID=s.JobID AND cp.ListID=s.ListID AND cp.BatchID=s.BatchID AND cp.SubscriberID=s.SubscriberID AND cp.IsUnique=1
WHERE s.EventDate >= '20260531 16:00:00'
  AND s.EventDate < '20261201 00:00:00'
  AND (j.JourneyName LIKE 'MKT[_]%' OR j.JourneyName LIKE 'O__[_]%')
  AND s.Domain IS NOT NULL
GROUP BY s.Domain, CONVERT(char(7), CAST(TODATETIMEOFFSET(s.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120)
HAVING COUNT(*) >= 20
