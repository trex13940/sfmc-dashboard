/* ============================================================================
   DIAGNOSTIC de l'erreur "could not convert date and/or time from string data type"
   (requête conversions, à l'EXÉCUTION). Deux causes possibles :
     (1) type des champs de la DE CIBLE DASH_Conversions (SendMonth/SendDate/LeadCreatedDate créés en "Date" au lieu de "Text")
     (2) colonne Lead_Salesforce.CreatedDate (valeurs texte illisibles)
   Chaque requête ci-dessous : cible DASH_Debug (Step Text(200) PK, N Number), mode Overwrite, Run Once.
   ============================================================================ */

/* ---- REQUÊTE E1 : à quoi ressemblent réellement CreatedDate et Status dans Lead_Salesforce ---- */
SELECT TOP 5 'CreatedDate=[' + CAST(CreatedDate AS varchar(60)) + '] Status=[' + CAST(Status AS varchar(60)) + '] Id=' + CAST(Id AS varchar(30)) AS Step, 1 AS N
FROM Lead_Salesforce
WHERE CreatedDate IS NOT NULL


/* ---- REQUÊTE E2 : le filtre de date sur les leads s'exécute-t-il ? (erreur ici = problème (2)) ---- */
SELECT 'Leads créés depuis 2026-05-31 16:00' AS Step, COUNT(*) AS N
FROM Lead_Salesforce
WHERE CreatedDate >= '20260531 16:00:00'
