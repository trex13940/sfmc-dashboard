SELECT u.Metric AS Metric, u.Month AS Month, u.N AS N
FROM (
    SELECT 'Leads created' AS Metric, t.Month AS Month, COUNT(*) AS N
    FROM (SELECT CONVERT(char(7), CAST(TODATETIMEOFFSET(CreatedDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS Month FROM Lead_Salesforce_1 WHERE CreatedDate IS NOT NULL) t
    GROUP BY t.Month
    UNION ALL
    SELECT 'Leads with an email and a tracked status' AS Metric, t.Month AS Month, COUNT(*) AS N
    FROM (SELECT CONVERT(char(7), CAST(TODATETIMEOFFSET(CreatedDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS Month FROM Lead_Salesforce_1
          WHERE CreatedDate IS NOT NULL AND Email IS NOT NULL AND Email <> ''
            AND Status IN ('Incomplete', 'Viewed Premium', 'Offer Incomplete', 'Offer Viewed', 'Offer Created', 'Signing', 'Signed')) t
    GROUP BY t.Month
    UNION ALL
    SELECT 'Leads whose email is in _Subscribers' AS Metric, t.Month AS Month, COUNT(*) AS N
    FROM (SELECT DISTINCT l.Id AS Id, CONVERT(char(7), CAST(TODATETIMEOFFSET(l.CreatedDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS Month
          FROM Lead_Salesforce_1 l
          JOIN _Subscribers sub ON sub.EmailAddress = l.Email
          WHERE l.CreatedDate IS NOT NULL) t
    GROUP BY t.Month
    UNION ALL
    SELECT 'Emails sent (_Sent)' AS Metric, t.Month AS Month, COUNT(*) AS N
    FROM (SELECT CONVERT(char(7), CAST(TODATETIMEOFFSET(EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS Month FROM _Sent WHERE EventDate >= '20260401 00:00:00') t
    GROUP BY t.Month
    UNION ALL
    SELECT 'Conversions in DASH_Conversions (by lead creation)' AS Metric, SUBSTRING(LeadCreatedDate, 1, 7) AS Month, COUNT(*) AS N
    FROM DASH_Conversions
    GROUP BY SUBSTRING(LeadCreatedDate, 1, 7)
) u
