/* Cible : DASH_Conversions | Mode : Update (upsert) | PK : LeadId | Exécution : quotidienne
   VERSION OPTIMISÉE (la version précédente partait de tous les envois -> trop lente) :
     1. on part des LEADS créés sur les 3 derniers mois (peu nombreux) et on remonte email -> _Subscribers -> _Sent
     2. ROW_NUMBER (last touch) sur un jeu de colonnes minimal
     3. _Open / _Click ne sont joints que pour l envoi retenu de chaque lead
     4. conversions de fuseau (AT TIME ZONE) uniquement sur les lignes finales ; plus de LOWER() sur l email
        (collation SFMC insensible à la casse par défaut ; si la vôtre est sensible, remettre LOWER() des 2 côtés)
   Hypothèses À ADAPTER : DE synchronisée "Lead_Salesforce_1" (Id, Email, Status, CreatedDate) ;
     IsConverted = 1 quand Status = "Signed" (modifier ce libellé si besoin) ; CreatedDate (champ date) supposé en CST (UTC-6) ; si UTC, remplacer "-06:00" par "+00:00" pour t.LeadCreated ;
     fenêtre d attribution 30 jours ; attribution last-touch (un lead = un seul envoi).
   Dates de sortie en CET/CEST (Europe/Brussels). */
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
              WHERE CreatedDate >= DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 3, 0) AND CreatedDate < DATEADD(day, 1, GETDATE())
                AND Email IS NOT NULL AND Email <> '') l
        JOIN _Subscribers sub ON sub.EmailAddress = l.Email
        JOIN _Sent s ON s.SubscriberID = sub.SubscriberID
                    AND s.EventDate >= DATEADD(day, -30, DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 3, 0))
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
