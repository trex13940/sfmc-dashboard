SELECT
    r.AsOf AS AsOf,
    r.Win AS Win,
    r.Contract AS Contract,
    r.RecBucket AS RecBucket,
    r.Seg AS Seg,
    COUNT(*) AS Subscribers,
    SUM(r.RecMkt) AS ReceivedMkt,
    SUM(r.RecOps) AS ReceivedOps,
    SUM(r.OpenMkt) AS OpensMkt,
    SUM(r.ClickMkt) AS ClicksMkt,
    MAX(r.Months) AS Months
FROM (
    SELECT cur.CurM AS AsOf,
           CAST(q.w AS varchar(2)) AS Win,
           q.Contract AS Contract,
           CASE WHEN q.RecMkt = 0 THEN '0' WHEN q.RecMkt <= 2 THEN '1-2' WHEN q.RecMkt <= 5 THEN '3-5' WHEN q.RecMkt <= 10 THEN '6-10' WHEN q.RecMkt <= 20 THEN '11-20' ELSE '21+' END AS RecBucket,
           CASE WHEN q.RecMkt = 0 THEN 'NotReached' WHEN q.ClickMkt > 0 THEN 'Clicker' WHEN q.OpenMkt > 0 THEN 'Opener' ELSE 'NoEngagement' END AS Seg,
           q.RecMkt AS RecMkt, q.RecOps AS RecOps, q.OpenMkt AS OpenMkt, q.ClickMkt AS ClickMkt,
           CASE WHEN mm.MinM IS NULL THEN 0 WHEN DATEDIFF(month, CAST(mm.MinM + '-01' AS date), CAST(cur.CurM + '-01' AS date)) < q.w THEN DATEDIFF(month, CAST(mm.MinM + '-01' AS date), CAST(cur.CurM + '-01' AS date)) ELSE q.w END AS Months
    FROM (SELECT a.SubscriberKey AS SubscriberKey, a.Contract AS Contract, w.w AS w,
            SUM(ISNULL(m.RecMkt, 0)) AS RecMkt, SUM(ISNULL(m.RecOps, 0)) AS RecOps,
            SUM(ISNULL(m.OpenMkt, 0)) AS OpenMkt, SUM(ISNULL(m.ClickMkt, 0)) AS ClickMkt
     FROM (SELECT s.SubscriberKey AS SubscriberKey,
            CASE WHEN k.ContactId IS NULL THEN 'No' ELSE 'Yes' END AS Contract
     FROM _Subscribers s
     LEFT JOIN (SELECT DISTINCT Contact__c AS ContactId FROM Contract_Salesforce_1 WHERE Status__c IN ('Active', 'Future')) k ON k.ContactId = s.SubscriberKey
     WHERE s.Status = 'Active' AND s.SubscriberKey NOT LIKE '00QP%') a
     CROSS JOIN (SELECT 3 AS w UNION ALL SELECT 6 UNION ALL SELECT 12) w
     CROSS JOIN (SELECT CONVERT(char(7), CAST(TODATETIMEOFFSET(GETDATE(), '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS CurM) cur
     LEFT JOIN DASH_Sub_Monthly m ON m.SubscriberKey = a.SubscriberKey
          AND m.[Month] >= CONVERT(char(7), DATEADD(month, -w.w, CAST(cur.CurM + '-01' AS date)), 120)
          AND m.[Month] < cur.CurM
     GROUP BY a.SubscriberKey, a.Contract, w.w) q
    CROSS JOIN (SELECT CONVERT(char(7), CAST(TODATETIMEOFFSET(GETDATE(), '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS CurM) cur
    CROSS JOIN (SELECT MIN([Month]) AS MinM FROM DASH_Sub_Monthly) mm
) r
GROUP BY r.AsOf, r.Win, r.Contract, r.RecBucket, r.Seg
