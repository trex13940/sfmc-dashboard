SELECT
    jn.JourneyName AS JourneyName,
    CONVERT(char(7), CAST(TODATETIMEOFFSET(sms.CreateDateTime, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS [Month],
    LEFT(ISNULL(sms.Name, ''), 200) AS AssetName,
    COUNT(*) AS Sent,
    COUNT(DISTINCT sms.Mobile) AS UniqueRecipients,
    SUM(CASE WHEN sms.Delivered = 1 THEN 1 ELSE 0 END) AS Delivered,
    SUM(CASE WHEN sms.Undelivered = 1 THEN 1 ELSE 0 END) AS Bounced
FROM _SMSMessageTracking sms
JOIN (SELECT CAST(JourneyID AS varchar(36)) AS JourneyID, MAX(JourneyName) AS JourneyName
      FROM _Journey
      GROUP BY CAST(JourneyID AS varchar(36))) jn
     ON jn.JourneyID = CAST(sms.JBDefinitionID AS varchar(36))
WHERE sms.CreateDateTime >= '20260531 16:00:00'
  AND sms.CreateDateTime < '20261201 00:00:00'
  AND sms.Outbound = 1
  AND (sms.IsTest = 0 OR sms.IsTest IS NULL)
  AND (jn.JourneyName LIKE 'MKT[_]%' OR jn.JourneyName LIKE 'O__[_]%')
GROUP BY jn.JourneyName, CONVERT(char(7), CAST(TODATETIMEOFFSET(sms.CreateDateTime, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120), LEFT(ISNULL(sms.Name, ''), 200)
