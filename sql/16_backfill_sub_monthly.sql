SELECT
    s.SubscriberKey AS SubscriberKey,
    CONVERT(char(7), CAST(TODATETIMEOFFSET(s.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS [Month],
    SUM(CASE WHEN j.JourneyName LIKE 'MKT[_]%' AND b.SubscriberID IS NULL THEN 1 ELSE 0 END) AS RecMkt,
    SUM(CASE WHEN j.JourneyName NOT LIKE 'MKT[_]%' AND b.SubscriberID IS NULL THEN 1 ELSE 0 END) AS RecOps,
    SUM(CASE WHEN j.JourneyName LIKE 'MKT[_]%' AND o.SubscriberID IS NOT NULL THEN 1 ELSE 0 END) AS OpenMkt,
    SUM(CASE WHEN j.JourneyName LIKE 'MKT[_]%' AND c.SubscriberID IS NOT NULL THEN 1 ELSE 0 END) AS ClickMkt
FROM _Sent s
JOIN _JourneyActivity ja ON ja.JourneyActivityObjectID = s.TriggererSendDefinitionObjectID
JOIN _Journey j ON j.VersionID = ja.VersionID
LEFT JOIN _Bounce b ON b.JobID=s.JobID AND b.ListID=s.ListID AND b.BatchID=s.BatchID AND b.SubscriberID=s.SubscriberID AND b.IsUnique=1
LEFT JOIN _Open o ON o.JobID=s.JobID AND o.ListID=s.ListID AND o.BatchID=s.BatchID AND o.SubscriberID=s.SubscriberID AND o.IsUnique=1
LEFT JOIN _Click c ON c.JobID=s.JobID AND c.ListID=s.ListID AND c.BatchID=s.BatchID AND c.SubscriberID=s.SubscriberID AND c.IsUnique=1
WHERE s.EventDate >= '20260531 16:00:00'
  AND s.EventDate < '20261201 00:00:00'
  AND (j.JourneyName LIKE 'MKT[_]%' OR j.JourneyName LIKE 'O__[_]%')
GROUP BY s.SubscriberKey, CONVERT(char(7), CAST(TODATETIMEOFFSET(s.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120)
