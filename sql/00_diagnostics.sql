/* ============================================================================
   DIAGNOSTIC : pourquoi 01_journey_kpi_monthly.sql / 02_conversions.sql ne renvoient rien ?
   Chaque requête renvoie des lignes (Step, N) = nombre de lignes restantes après chaque étape.
   Là où N tombe à 0, on a trouvé le problème.

   MODE D EMPLOI
   1. Créer une DE "DASH_Debug" : Step Text(200) (PK), N Number.
   2. Automation Studio > Activities > SQL Query > créer UNE activité par requête ci-dessous
      (A, B, C, D), cible DASH_Debug, mode OVERWRITE (une requête à la fois), puis "Run Once".
   3. Ouvrir DASH_Debug dans Contact Builder > Data Extensions > Records et noter les résultats.
   IMPORTANT : exécuter dans la Business Unit où tournent les journeys (les Data Views sont par BU).
   ============================================================================ */


/* ---------------------------------------------------------------------------
   REQUÊTE A : les jointures _Sent -> _JourneyActivity -> _Journey et le filtre de nom
   --------------------------------------------------------------------------- */
SELECT 'A1 _Sent (60 derniers jours)' AS Step, COUNT(*) AS N
FROM _Sent WHERE EventDate >= DATEADD(day, -60, GETDATE())
UNION ALL
SELECT 'A2 _Sent avec TriggererSendDefinitionObjectID (envois de journeys)', COUNT(*)
FROM _Sent WHERE EventDate >= DATEADD(day, -60, GETDATE()) AND TriggererSendDefinitionObjectID IS NOT NULL
UNION ALL
SELECT 'A3 + jointure _JourneyActivity (ObjectID)', COUNT(*)
FROM _Sent s JOIN _JourneyActivity ja ON ja.JourneyActivityObjectID = s.TriggererSendDefinitionObjectID
WHERE s.EventDate >= DATEADD(day, -60, GETDATE())
UNION ALL
SELECT 'A4 + jointure _Journey (VersionID)', COUNT(*)
FROM _Sent s JOIN _JourneyActivity ja ON ja.JourneyActivityObjectID = s.TriggererSendDefinitionObjectID
             JOIN _Journey j ON j.VersionID = ja.VersionID
WHERE s.EventDate >= DATEADD(day, -60, GETDATE())
UNION ALL
SELECT 'A5 + filtre nom MKT_ ou Oxx_', COUNT(*)
FROM _Sent s JOIN _JourneyActivity ja ON ja.JourneyActivityObjectID = s.TriggererSendDefinitionObjectID
             JOIN _Journey j ON j.VersionID = ja.VersionID
WHERE s.EventDate >= DATEADD(day, -60, GETDATE())
  AND (j.JourneyName LIKE 'MKT[_]%' OR j.JourneyName LIKE 'O__[_]%')
UNION ALL
SELECT 'A6 _Journey : lignes au total', COUNT(*) FROM _Journey
UNION ALL
SELECT 'A7 _Journey : noms MKT_ ou Oxx_', COUNT(*) FROM _Journey
WHERE JourneyName LIKE 'MKT[_]%' OR JourneyName LIKE 'O__[_]%'


/* ---------------------------------------------------------------------------
   REQUÊTE B : les noms de journeys réellement vus dans _Sent (top 40) -> vérifier préfixes/casse/espaces
   --------------------------------------------------------------------------- */
SELECT Step, N FROM (
    SELECT TOP 40 'J: [' + LEFT(j.JourneyName, 180) + ']' AS Step, COUNT(*) AS N
    FROM _Sent s
    JOIN _JourneyActivity ja ON ja.JourneyActivityObjectID = s.TriggererSendDefinitionObjectID
    JOIN _Journey j ON j.VersionID = ja.VersionID
    WHERE s.EventDate >= DATEADD(day, -60, GETDATE())
    GROUP BY LEFT(j.JourneyName, 180)
    ORDER BY COUNT(*) DESC
) x


/* ---------------------------------------------------------------------------
   REQUÊTE C : le fuseau horaire (AT TIME ZONE est-il accepté ? les dates passent-elles le filtre ?)
   Si cette requête provoque une ERREUR de syntaxe, AT TIME ZONE n est pas supporté -> le dire,
   les requêtes 01/02 seront réécrites sans cette fonction.
   --------------------------------------------------------------------------- */
SELECT 'C1 maintenant (CET)' + CONVERT(char(19), CAST(TODATETIMEOFFSET(GETDATE(), '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120) AS Step, 1 AS N
UNION ALL
SELECT 'C2 envois dont le mois CET >= mois précédent', COUNT(*)
FROM _Sent s
WHERE s.EventDate >= DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 2, 0)
  AND CONVERT(char(7), CAST(TODATETIMEOFFSET(s.EventDate, '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2), 120)
      >= CONVERT(char(7), DATEADD(month, -1, CAST(TODATETIMEOFFSET(GETDATE(), '-06:00') AT TIME ZONE 'Central European Standard Time' AS datetime2)), 120)


/* ---------------------------------------------------------------------------
   REQUÊTE D : conversions (02) - la DE de leads et la jointure par email
   Adapter "Lead_Salesforce_1" si la DE a un autre nom (préfixer "ent." si elle est dans la BU parente).
   --------------------------------------------------------------------------- */
SELECT 'D1 Lead_Salesforce_1 : lignes' AS Step, COUNT(*) AS N FROM Lead_Salesforce_1
UNION ALL
SELECT 'D2 Lead_Salesforce_1 : lignes avec Email', COUNT(*) FROM Lead_Salesforce_1 WHERE Email IS NOT NULL AND Email <> ''
UNION ALL
SELECT 'D3 envois de journeys (90 j) + _Subscribers', COUNT(*)
FROM _Sent s
JOIN _JourneyActivity ja ON ja.JourneyActivityObjectID = s.TriggererSendDefinitionObjectID
JOIN _Journey j ON j.VersionID = ja.VersionID
JOIN _Subscribers sub ON sub.SubscriberID = s.SubscriberID
WHERE s.EventDate >= DATEADD(day, -90, GETDATE())
  AND (j.JourneyName LIKE 'MKT[_]%' OR j.JourneyName LIKE 'O__[_]%')
UNION ALL
SELECT 'D4 + même email qu''un lead (sans condition de date)', COUNT(*)
FROM _Sent s
JOIN _JourneyActivity ja ON ja.JourneyActivityObjectID = s.TriggererSendDefinitionObjectID
JOIN _Journey j ON j.VersionID = ja.VersionID
JOIN _Subscribers sub ON sub.SubscriberID = s.SubscriberID
JOIN Lead_Salesforce_1 l ON LOWER(l.Email) = LOWER(sub.EmailAddress)
WHERE s.EventDate >= DATEADD(day, -90, GETDATE())
  AND (j.JourneyName LIKE 'MKT[_]%' OR j.JourneyName LIKE 'O__[_]%')
UNION ALL
SELECT 'D5 + lead créé APRES l''envoi, dans les 30 jours', COUNT(*)
FROM _Sent s
JOIN _JourneyActivity ja ON ja.JourneyActivityObjectID = s.TriggererSendDefinitionObjectID
JOIN _Journey j ON j.VersionID = ja.VersionID
JOIN _Subscribers sub ON sub.SubscriberID = s.SubscriberID
JOIN Lead_Salesforce_1 l ON LOWER(l.Email) = LOWER(sub.EmailAddress)
                      AND l.CreatedDate >= s.EventDate AND l.CreatedDate < DATEADD(day, 30, s.EventDate)
WHERE s.EventDate >= DATEADD(day, -90, GETDATE())
  AND (j.JourneyName LIKE 'MKT[_]%' OR j.JourneyName LIKE 'O__[_]%')
