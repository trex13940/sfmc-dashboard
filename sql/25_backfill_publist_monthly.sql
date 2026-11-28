SELECT
    u.ListName AS ListName,
    u.Month AS Month,
    SUM(u.Joined) AS Joined,
    SUM(u.Unsub) AS Unsubscribed
FROM (
    SELECT 'All Subscribers' AS ListName, CONVERT(char(7), CAST(TODATETIMEOFFSET(s.DateJoined, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS Month, 1 AS Joined, 0 AS Unsub
    FROM _Subscribers s
    WHERE s.SubscriberKey NOT LIKE '00QP%' AND s.DateJoined >= '20250101 00:00:00'
    UNION ALL
    SELECT 'All Subscribers' AS ListName, CONVERT(char(7), CAST(TODATETIMEOFFSET(s.DateUnsubscribed, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS Month, 0 AS Joined, 1 AS Unsub
    FROM _Subscribers s
    WHERE s.SubscriberKey NOT LIKE '00QP%' AND s.DateUnsubscribed IS NOT NULL AND s.DateUnsubscribed >= '20250101 00:00:00'
) u
GROUP BY u.ListName, u.Month
