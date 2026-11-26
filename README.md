# Dashboard Journeys SFMC

Architecture : Data Views → (Automation nocturne, SQL) → DE agrégées → CloudPage API (SSJS, JSON) → CloudPage dashboard (HTML/JS).
Les DE gardent l'historique au-delà des ~6 mois de rétention des Data Views.

## Data Extensions à créer
| DE | Champs (PK en gras) |
|---|---|
| DASH_Journey_KPI_Monthly | **JourneyName** Text(200), **Month** Text(7), Category Text(3), Sends, Bounces, Opens, UniqueClicks, Unsubscribes, Complaints (Number) |
| DASH_Conversions | **LeadId** Text(18), JourneyName Text(200), Category Text(3), SendMonth Text(7), SendDate Text(10), LeadCreatedDate Text(10), LeadStatus Text(100), IsConverted, DaysToLead, Opened, Clicked (Number) |
| DASH_Config | **ConfigKey** Text(50), Value Text(200) → une ligne `token` / secret aléatoire |
| DASH_IP_Allowlist | **IPAddress** Text(50), Description Text(200) → une ligne par IP (`203.0.113.7`) ou plage IPv4 CIDR (`203.0.113.0/24`) ; IPv6 en correspondance exacte |

## Automation Studio (quotidienne)
1. SQL `sql/01_journey_kpi_monthly.sql` → DASH_Journey_KPI_Monthly, **Update**
2. SQL `sql/02_conversions.sql` → DASH_Conversions, **Update** (nécessite la DE synchro `Lead_Salesforce`)

Premier chargement : retirer temporairement le filtre de date (`DATEADD(...)`) pour backfiller 6 mois.

## CloudPages
1. Page API : coller `cloudpage_api.html` → noter l'URL publiée.
2. Page dashboard : coller `cloudpage_dashboard.html`, remplacer `API_URL`.
3. Accès : `https://.../dashboard?k=<token>`.

## Contrôle IP
Les deux pages (dashboard + API) vérifient `Platform.Request.ClientIP` contre `DASH_IP_Allowlist` à chaque requête (fail closed : DE vide/absente = accès refusé). Pour autoriser une IP : ajouter une ligne dans la DE (Contact Builder / import). La page de refus affiche l'IP détectée.
Le token `?k=` reste exigé en plus.

## Fuseau horaire
Data Views et `GETDATE()` = CST fixe (UTC-6, sans DST). Les requêtes convertissent en CET/CEST (Europe/Brussels, DST inclus) via `TODATETIMEOFFSET(..., '-06:00') AT TIME ZONE 'Central European Standard Time'` : mois d'envoi, dates de leads et délais en jours calendaires sont en heure belge. L'horodatage « Data as of » est affiché en Europe/Brussels côté navigateur.
Après déploiement : relancer **une fois** les requêtes sans filtre de date (backfill) pour recalculer les anciens mois, qui avaient été calculés en CST.

## Naming convention & filtres
`MKT|Oxx_TYPE_PRODUIT_Nom de campagne_mmyyyy|ongoing` est parsé côté navigateur (aucun changement de DE/SQL). Les filtres *Campaign type* et *Product* se remplissent automatiquement avec les valeurs présentes. Noms non conformes → `n/a`.
Libellés lisibles : renseigner `LABELS.type` / `LABELS.product` en haut du script de `cloudpage_dashboard.html` (ex. `PROMO:'Promotional'`).
