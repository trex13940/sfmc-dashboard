/* BACKFILL (une seule fois) - Conversions depuis le 01/06/2026 (CET) | Cible : DASH_Conversions | Mode : Update
   Même requête que 02_conversions.sql, avec des dates fixes (en CST = heure des Data Views) :
     - leads créés à partir du 31/05/2026 16:00 CST  (= 01/06/2026 00:00 CEST)
     - envois à partir du 01/05/2026 (30 jours de fenêtre d attribution avant le 1er juin)
   SI LE TIMEOUT (30 min) EST ATTEINT : découper PAR MOIS DE CRÉATION DU LEAD, en lançant la requête plusieurs fois
   (le résultat est identique car chaque lead est traité indépendamment). Pour chaque passe, modifier 3 dates :
     Mois        | LEAD_FROM (>=)        | LEAD_TO (<)           | SEND_FROM (>=)
     Juin 2026   | 2026-05-31 16:00:00   | 2026-06-30 16:00:00   | 2026-05-01 00:00:00
     Juillet     | 2026-06-30 16:00:00   | 2026-07-31 16:00:00   | 2026-05-31 00:00:00
     Août        | 2026-07-31 16:00:00   | 2026-08-31 16:00:00   | 2026-06-30 00:00:00
     Septembre   | 2026-08-31 16:00:00   | 2026-09-30 16:00:00   | 2026-07-31 00:00:00
     Octobre     | 2026-09-30 16:00:00   | 2026-10-31 17:00:00   | 2026-08-31 00:00:00
     Novembre+   | 2026-10-31 17:00:00   | 2026-12-01 00:00:00   | 2026-09-30 00:00:00
   (LEAD_FROM/LEAD_TO = début/fin de mois belge converti en CST ; SEND_FROM = LEAD_FROM - ~31 jours.) 
   FORMAT DES DATES : dans le WHERE, écrire "AAAAMMJJ hh:mm:ss" (ex. "20260531 16:00:00") : indépendant de la langue du serveur. */
SELECT
    t.LeadId                                         AS LeadId,
    t.JourneyName                                    AS JourneyName,
    LEFT(t.JourneyName, 3)                           AS Category,
    CONVERT(char(7),  CAST(TODATETIMEOFFSET(t.EventDate,   '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS SendMonth,
    CONVERT(char(10), CAST(TODATETIMEOFFSET(t.EventDate,   '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS SendDate,
    CONVERT(char(10), CAST(TODATETIMEOFFSET(t.LeadCreated, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS LeadCreatedDate,
    t.LeadStatus                                     AS LeadStatus,
    CASE WHEN t.LeadStatus = 'Signed' THEN 1 ELSE 0 END  AS IsConverted   /* converti = statut "Signed" */,
    DATEDIFF(day,
        CAST(CAST(TODATETIMEOFFSET(t.EventDate,   '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2) AS date),
        CAST(CAST(TODATETIMEOFFSET(t.LeadCreated, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2) AS date)) AS DaysToLead,
    CASE WHEN o.SubscriberID IS NOT NULL THEN 1 ELSE 0 END AS Opened,
    CASE WHEN c.SubscriberID IS NOT NULL THEN 1 ELSE 0 END AS Clicked
FROM (
    /* 2) un seul envoi par lead : le dernier avant sa création (last touch) - colonnes minimales */
    SELECT x.LeadId, x.LeadStatus, x.LeadCreated, x.EventDate, x.JobID, x.ListID, x.BatchID, x.SubscriberID, x.JourneyName,
           ROW_NUMBER() OVER (PARTITION BY x.LeadId ORDER BY x.EventDate DESC) AS rn
    FROM (
        /* 1) on part des LEADS (peu nombreux), puis email -> subscriber -> envois de journeys MKT_/Oxx_ */
        SELECT l.Id AS LeadId, l.Status AS LeadStatus, l.CreatedDate AS LeadCreated,
               s.EventDate, s.JobID, s.ListID, s.BatchID, s.SubscriberID, j.JourneyName
        FROM (SELECT Id, Email, Status, CreatedDate
              FROM Lead_Salesforce_1
              WHERE CreatedDate >= '20260531 16:00:00' AND CreatedDate < '20261201 00:00:00'
                AND Email IS NOT NULL AND Email <> '') l
        JOIN _Subscribers sub ON sub.EmailAddress = l.Email
        JOIN _Sent s ON s.SubscriberID = sub.SubscriberID
                    AND s.EventDate >= '20260501 00:00:00'
                    AND s.EventDate <= l.CreatedDate
                    AND s.EventDate >  DATEADD(day, -30, l.CreatedDate)           /* fenêtre d attribution 30 j */
        JOIN _JourneyActivity ja ON ja.JourneyActivityObjectID = s.TriggererSendDefinitionObjectID
        JOIN _Journey j          ON j.VersionID = ja.VersionID
        WHERE (j.JourneyName LIKE 'MKT[_]%' OR j.JourneyName LIKE 'O__[_]%')
    ) x
) t
/* 3) opens/clicks uniquement pour les envois retenus (rn = 1) */
LEFT JOIN _Open  o ON o.JobID=t.JobID AND o.ListID=t.ListID AND o.BatchID=t.BatchID AND o.SubscriberID=t.SubscriberID AND o.IsUnique=1
LEFT JOIN _Click c ON c.JobID=t.JobID AND c.ListID=t.ListID AND c.BatchID=t.BatchID AND c.SubscriberID=t.SubscriberID AND c.IsUnique=1
WHERE t.rn = 1
