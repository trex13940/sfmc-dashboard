/* BACKFILL (une seule fois) - KPI mensuels depuis le 01/06/2026 (CET) | Cible : DASH_Journey_KPI_Monthly | Mode : Update
   Même requête que 01_journey_kpi_monthly.sql, avec une période fixe (dates en CST = heure des Data Views).
   Prérequis : les Data Views ne conservent qu environ 6 mois -> à lancer rapidement.
   SI LE TIMEOUT (30 min) EST ATTEINT : lancer plusieurs fois en changeant les 2 dates du WHERE (résultat identique, mois par mois) :
     Mois        | >=                    | <
     Juin 2026   | 2026-05-31 16:00:00   | 2026-06-30 16:00:00
     Juillet     | 2026-06-30 16:00:00   | 2026-07-31 16:00:00
     Août        | 2026-07-31 16:00:00   | 2026-08-31 16:00:00
     Septembre   | 2026-08-31 16:00:00   | 2026-09-30 16:00:00
     Octobre     | 2026-09-30 16:00:00   | 2026-10-31 17:00:00
     Novembre    | 2026-10-31 17:00:00   | 2026-11-30 17:00:00
     Décembre    | 2026-11-30 17:00:00   | 2026-12-31 17:00:00 
   FORMAT DES DATES : dans le WHERE, écrire "AAAAMMJJ hh:mm:ss" (ex. "20260531 16:00:00") : indépendant de la langue du serveur. */
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
WHERE s.EventDate >= '20260531 16:00:00'          /* 01/06/2026 00:00 CEST exprimé en CST */
  AND s.EventDate <  '20261201 00:00:00'          /* fin de la période (CST) */
  AND (j.JourneyName LIKE 'MKT[_]%' OR j.JourneyName LIKE 'O__[_]%')           /* MKT_ ou Oxx_ */
GROUP BY j.JourneyName, CONVERT(char(7), CAST(TODATETIMEOFFSET(s.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120), LEFT(j.JourneyName, 3)
