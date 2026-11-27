SELECT
    x.JourneyName AS JourneyName,
    x.Mo AS [Month],
    x.AssetName AS AssetName,
    SUM(x.SMSCount) AS Sent,
    COUNT(*) AS Messages,
    COUNT(DISTINCT x.SubscriberKey) AS UniqueRecipients,
    SUM(CASE WHEN x.Deliv = 1 THEN x.SMSCount ELSE 0 END) AS Delivered,
    SUM(CASE WHEN x.Undeliv = 1 THEN x.SMSCount ELSE 0 END) AS Bounced
FROM (
    SELECT i.JourneyName, i.AssetName, i.SubscriberKey, i.SMSCount, i.Deliv, i.Undeliv,
           CONVERT(char(7), CAST(TODATETIMEOFFSET(i.CreateDT, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS Mo
    FROM (
        SELECT
            jn.JourneyName AS JourneyName,
            LEFT(ISNULL(jn.ActivityName, ''), 200) AS AssetName,
            t.SubscriberKey AS SubscriberKey,
            t.CreateDateTime AS CreateDT,
            CAST(CEILING(CAST(LEN(REPLACE(STRING_AGG(t.MessageText, '|') WITHIN GROUP (ORDER BY t.Ordinal ASC), '|', '')) AS numeric) / 153) AS int) AS SMSCount,
            MAX(CASE WHEN t.Delivered = 1 THEN 1 ELSE 0 END) AS Deliv,
            MAX(CASE WHEN t.Undelivered = 1 THEN 1 ELSE 0 END) AS Undeliv
        FROM _SMSMessageTracking t
        JOIN (SELECT a.ActivityID, a.ActivityName, a.JourneyName
              FROM (SELECT ja.ActivityID, ja.ActivityName, j.JourneyName,
                           ROW_NUMBER() OVER (PARTITION BY ja.ActivityID ORDER BY j.VersionNumber DESC) AS rn
                    FROM _JourneyActivity ja
                    JOIN _Journey j ON j.VersionID = ja.VersionID) a
              WHERE a.rn = 1) jn
             ON t.JBActivityID = jn.ActivityID
        WHERE t.CreateDateTime >= '20260531 16:00:00'
          AND t.CreateDateTime < '20261201 00:00:00'
          AND (t.IsTest = 0 OR t.IsTest IS NULL)
          AND (jn.JourneyName LIKE 'MKT[_]%' OR jn.JourneyName LIKE 'O__[_]%')
        GROUP BY jn.JourneyName, jn.ActivityName, t.SubscriberKey, t.CreateDateTime, t.JBActivityID
    ) i
) x
GROUP BY x.JourneyName, x.Mo, x.AssetName
