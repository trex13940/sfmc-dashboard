/* Sondes des DE de listes de publication.
   A. Query Studio (interactif, sans DE cible) : lancer ces 4 requetes une par une et noter les colonnes de chaque DE (cle, statut, dates...). */
SELECT TOP 5 * FROM List_Info

SELECT TOP 5 * FROM List_Newsletter

SELECT TOP 5 * FROM List_Promo

SELECT TOP 5 * FROM List_Survey

/* B. Automation Studio : nombre de lignes et de cles distinctes de chaque DE. Cible DASH_Debug (Step Text(200) PK, N Number), Overwrite, Run Once.
   Si une requete echoue sur SubscriberKey, la cle de la DE porte un autre nom : l indiquer. */
SELECT 'List_Info lignes' AS Step, COUNT(*) AS N FROM List_Info
UNION ALL SELECT 'List_Info cles distinctes', COUNT(DISTINCT SubscriberKey) FROM List_Info
UNION ALL SELECT 'List_Newsletter lignes', COUNT(*) FROM List_Newsletter
UNION ALL SELECT 'List_Newsletter cles distinctes', COUNT(DISTINCT SubscriberKey) FROM List_Newsletter
UNION ALL SELECT 'List_Promo lignes', COUNT(*) FROM List_Promo
UNION ALL SELECT 'List_Promo cles distinctes', COUNT(DISTINCT SubscriberKey) FROM List_Promo
UNION ALL SELECT 'List_Survey lignes', COUNT(*) FROM List_Survey
UNION ALL SELECT 'List_Survey cles distinctes', COUNT(DISTINCT SubscriberKey) FROM List_Survey
