/* Cible : DASH_Conversions | Mode : Update (upsert) | PK : LeadId
   Hypothèses À ADAPTER :
     - DE synchronisée "Lead_Salesforce" (Id, Email, Status, IsConverted, CreatedDate)
     - Jointure sur l'email (le lead n'existe pas encore à l'envoi -> pas de SubscriberKey = LeadId).
       Si SubscriberKey = ContactId/LeadId : remplacer la jointure _Subscribers par
       l.Id = s.SubscriberKey
     - Fenêtre d'attribution : 30 jours après l'envoi
   FUSEAU : s.EventDate ET l.CreatedDate sont supposés en CST fixe (UTC-6) — c'est le stockage
   standard de SFMC, y compris pour les DE synchronisées. Si CreatedDate est en UTC chez vous,
   remplacer '-06:00' par '+00:00' dans l.CreatedDate.
   Toutes les dates de sortie sont en CET/CEST (Europe/Brussels).
   Attribution "last touch" : chaque lead est rattaché à UN seul envoi (le dernier avant sa création),
   donc la somme des leads par journey = nombre réel de leads (pas de double comptage). */
SELECT LeadId, JourneyName, Category, SendMonth, SendDate, LeadCreatedDate, LeadStatus, IsConverted, DaysToLead, Opened, Clicked
FROM (
    SELECT
        l.Id                                         AS LeadId,
        j.JourneyName                                AS JourneyName,
        LEFT(j.JourneyName, 3)                       AS Category,
        CONVERT(char(7),  CAST(TODATETIMEOFFSET(s.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120)              AS SendMonth,
        CONVERT(char(10), CAST(TODATETIMEOFFSET(s.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120)              AS SendDate,
        CONVERT(char(10), CAST(TODATETIMEOFFSET(l.CreatedDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120)              AS LeadCreatedDate,
        l.Status                                     AS LeadStatus,
        CASE WHEN l.IsConverted = 1 THEN 1 ELSE 0 END AS IsConverted,
        DATEDIFF(day, CAST(CAST(TODATETIMEOFFSET(s.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2) AS date), CAST(CAST(TODATETIMEOFFSET(l.CreatedDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2) AS date)) AS DaysToLead,  /* jours calendaires CET */
        CASE WHEN o.SubscriberID IS NOT NULL THEN 1 ELSE 0 END AS Opened,
        CASE WHEN c.SubscriberID IS NOT NULL THEN 1 ELSE 0 END AS Clicked,
        ROW_NUMBER() OVER (PARTITION BY l.Id ORDER BY s.EventDate DESC) AS rn
    FROM _Sent s
    JOIN _JourneyActivity ja ON ja.JourneyActivityObjectID = s.TriggererSendDefinitionObjectID   /* ObjectID seul */
    JOIN _Journey j          ON j.VersionID = ja.VersionID
    JOIN _Subscribers sub    ON sub.SubscriberID = s.SubscriberID
    JOIN Lead_Salesforce l   ON LOWER(l.Email) = LOWER(sub.EmailAddress)
                            AND l.CreatedDate >= s.EventDate                    /* même fuseau des deux côtés */
                            AND l.CreatedDate <  DATEADD(day, 30, s.EventDate)
    LEFT JOIN _Open  o ON o.JobID=s.JobID AND o.ListID=s.ListID AND o.BatchID=s.BatchID AND o.SubscriberID=s.SubscriberID AND o.IsUnique=1
    LEFT JOIN _Click c ON c.JobID=s.JobID AND c.ListID=s.ListID AND c.BatchID=s.BatchID AND c.SubscriberID=s.SubscriberID AND c.IsUnique=1
    WHERE s.EventDate >= DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 3, 0)   /* pré-filtre large (CST) */
      AND CONVERT(char(7), CAST(TODATETIMEOFFSET(s.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120)
          >= CONVERT(char(7), DATEADD(month, -2, CAST(TODATETIMEOFFSET(GETDATE(), '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2)), 120)               /* 3 mois glissants, en CET */
      AND (j.JourneyName LIKE 'MKT[_]%' OR j.JourneyName LIKE 'O__[_]%')
) t
WHERE rn = 1
