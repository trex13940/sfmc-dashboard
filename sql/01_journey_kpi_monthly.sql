/* Cible : DASH_Journey_KPI_Monthly  | Mode : Update (upsert)  | PK : JourneyName + Month
   Rafraîchit le mois courant + le mois précédent (les Data Views ne gardent que ~6 mois :
   l historique plus ancien reste dans la DE, jamais écrasé).
   Attribution par mois d ENVOI (cohorte) : opens/clicks/etc. sont rattachés au mois du send.
   Seuls les événements IsUnique=1 sont joints -> pas de multiplication de lignes.
   FUSEAU : EventDate / GETDATE() sont en CST fixe (UTC-6, sans DST). Ils sont convertis en CET/CEST
   (Europe/Brussels, DST inclus) via TODATETIMEOFFSET + AT TIME ZONE ; les mois sont donc ceux de Belgique. */
SELECT
    j.JourneyName                                   AS JourneyName,
    CONVERT(char(7), CAST(TODATETIMEOFFSET(s.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120)                  AS [Month],
    LEFT(j.JourneyName, 3)                          AS Category,
    COUNT(*)                                        AS Sends,
    COUNT(b.SubscriberID)                           AS Bounces,
    COUNT(o.SubscriberID)                           AS Opens,
    COUNT(c.SubscriberID)                           AS UniqueClicks,
    COUNT(u.SubscriberID)                           AS Unsubscribes,
    COUNT(cp.SubscriberID)                          AS Complaints
FROM _Sent s
JOIN _JourneyActivity ja
     ON  ja.JourneyActivityObjectID = s.TriggererSendDefinitionObjectID   /* ObjectID seul : ActivityExternalKey = TriggeredSendCustomerKey ne correspond pas chez nous */
JOIN _Journey j
     ON  j.VersionID = ja.VersionID
LEFT JOIN _Bounce b       ON b.JobID=s.JobID  AND b.ListID=s.ListID  AND b.BatchID=s.BatchID  AND b.SubscriberID=s.SubscriberID  AND b.IsUnique=1
LEFT JOIN _Open o         ON o.JobID=s.JobID  AND o.ListID=s.ListID  AND o.BatchID=s.BatchID  AND o.SubscriberID=s.SubscriberID  AND o.IsUnique=1
LEFT JOIN _Click c        ON c.JobID=s.JobID  AND c.ListID=s.ListID  AND c.BatchID=s.BatchID  AND c.SubscriberID=s.SubscriberID  AND c.IsUnique=1
LEFT JOIN _Unsubscribe u  ON u.JobID=s.JobID  AND u.ListID=s.ListID  AND u.BatchID=s.BatchID  AND u.SubscriberID=s.SubscriberID  AND u.IsUnique=1
LEFT JOIN _Complaint cp   ON cp.JobID=s.JobID AND cp.ListID=s.ListID AND cp.BatchID=s.BatchID AND cp.SubscriberID=s.SubscriberID AND cp.IsUnique=1
WHERE s.EventDate >= DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 2, 0)     /* pré-filtre large (CST) */
  AND CONVERT(char(7), CAST(TODATETIMEOFFSET(s.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120)
      >= CONVERT(char(7), DATEADD(month, -1, CAST(TODATETIMEOFFSET(GETDATE(), '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2)), 120)                  /* mois précédent, en CET */
  AND (j.JourneyName LIKE 'MKT[_]%' OR j.JourneyName LIKE 'O__[_]%')           /* MKT_ ou Oxx_ */
GROUP BY j.JourneyName, CONVERT(char(7), CAST(TODATETIMEOFFSET(s.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120), LEFT(j.JourneyName, 3)
