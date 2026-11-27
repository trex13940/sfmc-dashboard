SELECT
    r.AsOf AS AsOf,
    r.Win AS Win,
    r.PostalCode AS PostalCode,
    COUNT(*) AS Subscribers,
    SUM(CASE WHEN r.RecMkt > 0 THEN 1 ELSE 0 END) AS Reached,
    SUM(CASE WHEN r.OpenMkt > 0 OR r.ClickMkt > 0 THEN 1 ELSE 0 END) AS Engaged,
    SUM(CASE WHEN r.ClickMkt > 0 THEN 1 ELSE 0 END) AS Clickers,
    SUM(r.RecMkt) AS ReceivedMkt,
    SUM(r.RecOps) AS ReceivedOps
FROM (
    SELECT cur.CurM AS AsOf,
           CAST(q.w AS varchar(2)) AS Win,
           q.PostalCode AS PostalCode, q.RecMkt AS RecMkt, q.RecOps AS RecOps, q.OpenMkt AS OpenMkt, q.ClickMkt AS ClickMkt
    FROM (SELECT a.SubscriberKey AS SubscriberKey, a.PostalCode AS PostalCode, w.w AS w,
            SUM(ISNULL(m.RecMkt, 0)) AS RecMkt, SUM(ISNULL(m.RecOps, 0)) AS RecOps,
            SUM(ISNULL(m.OpenMkt, 0)) AS OpenMkt, SUM(ISNULL(m.ClickMkt, 0)) AS ClickMkt
     FROM (SELECT z.SubscriberKey AS SubscriberKey,
                   CASE WHEN z.P1 LIKE '[0-9][0-9][0-9][0-9]' THEN CASE WHEN CAST(z.P1 AS int) BETWEEN 1000 AND 9999 THEN z.P1 ELSE 'N/A' END ELSE 'N/A' END AS PostalCode
            FROM (SELECT s.SubscriberKey AS SubscriberKey,
                         LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(UPPER(ISNULL(c.MailingPostalCode, '')), 'BE-', ''), 'B-', ''), 'BE ', ''))) AS P1
                  FROM _Subscribers s
                  LEFT JOIN Contact_Salesforce_1 c ON c.Id = s.SubscriberKey
                  WHERE s.Status = 'Active') z) a
     CROSS JOIN (SELECT 3 AS w UNION ALL SELECT 6 UNION ALL SELECT 12) w
     CROSS JOIN (SELECT CONVERT(char(7), CAST(TODATETIMEOFFSET(GETDATE(), '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS CurM) cur
     LEFT JOIN DASH_Sub_Monthly m ON m.SubscriberKey = a.SubscriberKey
          AND m.[Month] >= CONVERT(char(7), DATEADD(month, -w.w, CAST(cur.CurM + '-01' AS date)), 120)
          AND m.[Month] < cur.CurM
     GROUP BY a.SubscriberKey, a.PostalCode, w.w) q
    CROSS JOIN (SELECT CONVERT(char(7), CAST(TODATETIMEOFFSET(GETDATE(), '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS CurM) cur
) r
GROUP BY r.AsOf, r.Win, r.PostalCode
