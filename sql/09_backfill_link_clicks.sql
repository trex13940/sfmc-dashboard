SELECT
    CONVERT(varchar(32), HASHBYTES('MD5', ISNULL(t.JourneyName,'') + '|' + t.[Month] + '|' + ISNULL(t.EmailName,'') + '|' + t.LinkName + '|' + t.LinkContent), 2) AS RowKey,
    t.JourneyName AS JourneyName,
    t.[Month] AS [Month],
    t.EmailName AS EmailName,
    t.LinkName AS LinkName,
    t.LinkContent AS LinkContent,
    t.UniqueClicks AS UniqueClicks,
    t.TotalClicks AS TotalClicks
FROM (
    SELECT
        j.JourneyName AS JourneyName,
        CONVERT(char(7), CAST(TODATETIMEOFFSET(s.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS [Month],
        jb.EmailName AS EmailName,
        LEFT(ISNULL(c.LinkName, ''), 300) AS LinkName,
        LEFT(ISNULL(c.LinkContent, ''), 300) AS LinkContent,
        SUM(CASE WHEN c.IsUnique = 1 THEN 1 ELSE 0 END) AS UniqueClicks,
        COUNT(*) AS TotalClicks
    FROM _Click c
    JOIN _Sent s ON s.JobID=c.JobID AND s.ListID=c.ListID AND s.BatchID=c.BatchID AND s.SubscriberID=c.SubscriberID
    JOIN _JourneyActivity ja ON ja.JourneyActivityObjectID = s.TriggererSendDefinitionObjectID
    JOIN _Journey j ON j.VersionID = ja.VersionID
    JOIN _Job jb ON jb.JobID = c.JobID
    WHERE s.EventDate >= '20260531 16:00:00'
      AND s.EventDate < '20261201 00:00:00'
      AND (j.JourneyName LIKE 'MKT[_]%' OR j.JourneyName LIKE 'O__[_]%')
    GROUP BY j.JourneyName, CONVERT(char(7), CAST(TODATETIMEOFFSET(s.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120), jb.EmailName, LEFT(ISNULL(c.LinkName, ''), 300), LEFT(ISNULL(c.LinkContent, ''), 300)
) t
