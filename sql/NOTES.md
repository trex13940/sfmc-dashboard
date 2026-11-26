# Notes sur les requêtes SQL

Les fichiers `.sql` ne contiennent volontairement **aucun commentaire** : Automation Studio refuse parfois (`Incorrect syntax near the keyword SELECT`) les requêtes avec commentaires, et signale les apostrophes dans les commentaires. Les explications sont ici.

## 01_journey_kpi_monthly.sql
```
Cible : DASH_Journey_KPI_Monthly  | Mode : Update (upsert)  | PK : JourneyName + Month
   Rafraîchit le mois courant + le mois précédent (les Data Views ne gardent que ~6 mois :
   l historique plus ancien reste dans la DE, jamais écrasé).
   Attribution par mois d ENVOI (cohorte) : opens/clicks/etc. sont rattachés au mois du send.
   Seuls les événements IsUnique=1 sont joints -> pas de multiplication de lignes.
   FUSEAU : EventDate / GETDATE() sont en CST fixe (UTC-6, sans DST). Ils sont convertis en CET/CEST
   (Europe/Brussels, DST inclus) via TODATETIMEOFFSET + AT TIME ZONE ; les mois sont donc ceux de Belgique.
```
```
ObjectID seul : ActivityExternalKey = TriggeredSendCustomerKey ne correspond pas chez nous
```
```
pré-filtre large (CST)
```
```
mois précédent, en CET
```
```
MKT_ ou Oxx_
```

## 02_conversions.sql
```
Cible : DASH_Conversions | Mode : Update (upsert) | PK : LeadId | Exécution : quotidienne
   VERSION OPTIMISÉE (la version précédente partait de tous les envois -> trop lente) :
     1. on part des LEADS créés sur les 3 derniers mois (peu nombreux) et on remonte email -> _Subscribers -> _Sent
     2. ROW_NUMBER (last touch) sur un jeu de colonnes minimal
     3. _Open / _Click ne sont joints que pour l envoi retenu de chaque lead
     4. conversions de fuseau (AT TIME ZONE) uniquement sur les lignes finales ; plus de LOWER() sur l email
        (collation SFMC insensible à la casse par défaut ; si la vôtre est sensible, remettre LOWER() des 2 côtés)
   Hypothèses À ADAPTER : DE synchronisée "Lead_Salesforce_1" (Id, Email, Status, CreatedDate) ;
     IsConverted = 1 quand Status = "Signed" (modifier ce libellé si besoin) ; CreatedDate (champ date) supposé en CST (UTC-6) ; si UTC, remplacer "-06:00" par "+00:00" pour t.LeadCreated ;
     fenêtre d attribution 30 jours ; attribution last-touch (un lead = un seul envoi).
   Dates de sortie en CET/CEST (Europe/Brussels).
```
```
converti = statut "Signed"
```
```
2) un seul envoi par lead : le dernier avant sa création (last touch) - colonnes minimales
```
```
1) on part des LEADS (peu nombreux), puis email -> subscriber -> envois de journeys MKT_/Oxx_
```
```
fenêtre d attribution 30 j
```
```
3) opens/clicks uniquement pour les envois retenus (rn = 1)
```

## 03_backfill_kpi.sql
```
BACKFILL (une seule fois) - KPI mensuels depuis le 01/06/2026 (CET) | Cible : DASH_Journey_KPI_Monthly | Mode : Update
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
   FORMAT DES DATES : dans le WHERE, écrire "AAAAMMJJ hh:mm:ss" (ex. "20260531 16:00:00") : indépendant de la langue du serveur.
```
```
ObjectID seul : ActivityExternalKey = TriggeredSendCustomerKey ne correspond pas chez nous
```
```
01/06/2026 00:00 CEST exprimé en CST
```
```
fin de la période (CST)
```
```
MKT_ ou Oxx_
```

## 04_backfill_conversions.sql
```
BACKFILL (une seule fois) - Conversions depuis le 01/06/2026 (CET) | Cible : DASH_Conversions | Mode : Update
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
   FORMAT DES DATES : dans le WHERE, écrire "AAAAMMJJ hh:mm:ss" (ex. "20260531 16:00:00") : indépendant de la langue du serveur.
```
```
converti = statut "Signed"
```
```
2) un seul envoi par lead : le dernier avant sa création (last touch) - colonnes minimales
```
```
1) on part des LEADS (peu nombreux), puis email -> subscriber -> envois de journeys MKT_/Oxx_
```
```
fenêtre d attribution 30 j
```
```
3) opens/clicks uniquement pour les envois retenus (rn = 1)
```
