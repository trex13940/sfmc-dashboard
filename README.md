# Dashboard Journeys SFMC

Architecture : Data Views → (Automation nocturne, SQL) → DE agrégées → CloudPage API (SSJS, JSON) → CloudPage dashboard (HTML/JS).
Les DE gardent l'historique au-delà des ~6 mois de rétention des Data Views.

## Data Extensions à créer
| DE | Champs (PK en gras) |
|---|---|
| DASH_Journey_KPI_Monthly | **JourneyName** Text(200), **Month** Text(7), Category Text(3), Sends, Bounces, Opens, UniqueClicks, Unsubscribes, Complaints (Number) |
| DASH_Conversions | **LeadId** Text(18), JourneyName Text(200), Category Text(50), SendMonth Text(7), SendDate Text(50), LeadCreatedDate Text(50), LeadStatus Text(100), **Product Text(20), LeadProduct Text(20), EmailName Text(200)** (nouveaux champs), IsConverted, DaysToLead, Opened, Clicked (Number) |
| DASH_Email_KPI_Monthly | **JourneyName** Text(200), **Month** Text(7), **EmailName** Text(200), Sends, Bounces, Opens, UniqueClicks, Unsubscribes, Complaints (Number) |
| DASH_Link_Monthly | **RowKey** Text(32), JourneyName Text(200), Month Text(7), EmailName Text(200), LinkName Text(300), LinkContent Text(300), UniqueClicks, TotalClicks (Number) |
| DASH_Domain_Monthly | **Domain** Text(100), **Month** Text(7), Sends, Bounces, Complaints (Number) |
| DASH_SMS_Monthly | **JourneyName** Text(200), **Month** Text(7), **AssetName** Text(200), Sent, UniqueRecipients, Delivered, Bounced (Number) |
| DASH_Config | **ConfigKey** Text(50), Value Text(200) → voir « Token d'accès » ci-dessous |
| DASH_IP_Allowlist | **IPAddress** Text(50), Description Text(200) → une ligne par IP (`203.0.113.7`) ou plage IPv4 CIDR (`203.0.113.0/24`) ; IPv6 en correspondance exacte |

## Token d'accès (DASH_Config)
La DE a deux colonnes. Ajoutez **une seule ligne** :

| ConfigKey | Value |
|---|---|
| `token` | votre secret, par ex. `k7Xp92QmZ4aTr8LwB3` |

- `ConfigKey` doit contenir exactement le mot `token` (minuscules) : c'est le nom du réglage que l'API cherche.
- `Value` contient la clé secrète de votre choix (chaîne aléatoire longue, sans espace).
- Le dashboard s'ouvre ensuite avec ce secret dans l'URL : `https://.../dashboard?k=k7Xp92QmZ4aTr8LwB3`. Sans `?k=` ou avec une autre valeur, l'API répond `unauthorized`.
- Pour changer le secret : modifiez `Value`, puis mettez à jour le lien enregistré dans vos favoris.

Si les DE n'ont pas une Customer Key identique à leur nom, adaptez `IP_DE_KEY`/`IP_DE_NAME` (allowlist) et `CFG_DE_KEY`/`CFG_DE_NAME` (token) en haut des scripts des CloudPages.

## Automation Studio (quotidienne)
1. SQL `sql/01_journey_kpi_monthly.sql` → DASH_Journey_KPI_Monthly, **Update**
2. SQL `sql/02_conversions.sql` → DASH_Conversions, **Update** (nécessite la DE synchro `Lead_Salesforce_1`)
3. SQL `sql/06_email_kpi_monthly.sql` → DASH_Email_KPI_Monthly, **Update**
4. SQL `sql/08_link_clicks_monthly.sql` → DASH_Link_Monthly, **Update**
5. SQL `sql/10_domain_monthly.sql` → DASH_Domain_Monthly, **Update**
6. SQL `sql/13_sms_monthly.sql` → DASH_SMS_Monthly, **Update** (backfill : `sql/14_backfill_sms.sql`)

Premier chargement (backfill depuis le 01/06/2026) : lancer **une fois** `sql/03_backfill_kpi.sql`, `04_backfill_conversions.sql`, `07_backfill_email_kpi.sql`, `09_backfill_link_clicks.sql` et `11_backfill_domain.sql` (Run Once, mêmes DE cibles, mode Update), puis activer les requêtes récurrentes 01 et 02. Si le timeout de 30 min est atteint, chaque fichier contient un tableau de dates pour découper le chargement mois par mois. Les fichiers SQL des automations ne contiennent aucun commentaire (Automation Studio les refuse parfois) : voir `sql/NOTES.md`. `sql/00_diagnostics.sql` sert à comprendre un résultat vide.

## CloudPages
1. Page API : coller `cloudpage_api.html` → noter l'URL publiée.
2. Page dashboard : coller `cloudpage_dashboard.html`, remplacer `API_URL`.
3. Accès : `https://.../dashboard?k=<token>`.

## Contrôle IP
Les deux pages (dashboard + API) vérifient `Platform.Request.ClientIP` contre `DASH_IP_Allowlist` à chaque requête (fail closed : DE vide/absente = accès refusé). Pour autoriser une IP : ajouter une ligne dans la DE (Contact Builder / import). La page de refus affiche l'IP détectée.
Le token `?k=` (voir « Token d'accès ») reste exigé en plus : l'IP et le token doivent être valides.

## Fuseau horaire
Data Views et `GETDATE()` = CST fixe (UTC-6, sans DST). Les requêtes convertissent en CET/CEST (Europe/Brussels, DST inclus) via `TODATETIMEOFFSET(..., '-06:00') AT TIME ZONE 'Central European Standard Time'` : mois d'envoi, dates de leads et délais en jours calendaires sont en heure belge. L'horodatage « Data as of » est affiché en Europe/Brussels côté navigateur.
Après déploiement : relancer **une fois** les requêtes sans filtre de date (backfill) pour recalculer les anciens mois, qui avaient été calculés en CST.

## Naming convention & filtres
`MKT|Oxx_TYPE_PRODUIT_Nom de campagne_mmyyyy|ongoing` est parsé côté navigateur (aucun changement de DE/SQL). Les filtres *Campaign type* et *Product* se remplissent automatiquement avec les valeurs présentes. Noms non conformes → `n/a`.
Libellés lisibles : renseigner `LABELS.type` / `LABELS.product` en haut du script de `cloudpage_dashboard.html` (ex. `PROMO:'Promotional'`).


## Onglets du dashboard
- **Journeys** : triées de la plus récente à la plus ancienne ; colonnes Campaign, Month (mois couvert), Family, Type, Product ; option *Detail* = Journey + email activity.
- **Categories** : vue par préfixe, type de campagne ou produit.
- **Conversions (leads)** : leads attribués (voir `sql/NOTES.md` pour les règles) ; regroupement possible par activité email.
- **Journey analysis** : une journey en détail : langues FR/NL, emails, KPI et liste des liens (chargée à la demande).
- **Insights** : top 5 des domaines (envois, bounces, complaints) et top 5 des journeys par bounces.
- **Alerts** : volume du mois en cours comparé au mois précédent (ramené au prorata des jours écoulés) ; alerte si plus de 15 % en dessous, pour les journeys de plus de 500 envois le mois dernier. Réglages `ALERT_DROP`, `ALERT_MIN`, `ALERT_MIN_DAYS` en haut du script du dashboard.
- **SMS** : par journey et asset (DASH_SMS_Monthly, requêtes 13 et 14).

L'API (`cloudpage_api.html`) renvoie les données principales par défaut ; `&part=links` et `&part=sms` sont chargés à la demande.

## Convention de nommage des emails (activités)
`MKT|Oxx_Type_Produit_Campagne[-info]_FR|NL_EMx_mmyyyy|ongoing`. Le split par activité ignore la langue, `EMx`, la période et tout ce qui suit un `-` dans le nom de campagne. BIKE devient BIK. Pour les produits PET et HOM, le détail cat/dog ou renters/owner est lu dans le nom.
