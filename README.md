# Dashboard Journeys SFMC

Architecture : Data Views → (Automation nocturne, SQL) → DE agrégées → CloudPage API (SSJS, JSON) → CloudPage dashboard (HTML/JS).
Les DE gardent l'historique au-delà des ~6 mois de rétention des Data Views.

## Data Extensions à créer
| DE | Champs (PK en gras) |
|---|---|
| DASH_Journey_KPI_Monthly | **JourneyName** Text(200), **Month** Text(7), Category Text(3), Sends, Bounces, Opens, UniqueClicks, Unsubscribes, Complaints (Number) |
| DASH_Conversions | **LeadId** Text(18), JourneyName Text(200), Category Text(50), SendMonth Text(7), SendDate Text(50), LeadCreatedDate Text(50), LeadStatus Text(100), **Product Text(20), LeadProduct Text(20), EmailName Text(200)** (nouveaux champs), IsConverted, DaysToLead, Opened, Clicked (Number) |
| DASH_Email_KPI_Monthly | **JourneyName** Text(200), **Month** Text(7), **EmailName** Text(200), Sends, Bounces, Opens, UniqueClicks, Unsubscribes, Complaints (Number) |
| DASH_Link_Monthly | **JourneyName** Text(200), **Month** Text(7), **RowKey** Text(32) (clé primaire composée dans cet ordre, pour des lectures rapides), EmailName Text(200), LinkName Text(300), LinkContent Text(300), UniqueClicks, TotalClicks (Number) |
| DASH_Domain_Monthly | **Domain** Text(100), **Month** Text(7), Sends, Bounces, Complaints (Number) |
| DASH_Sub_Monthly | **SubscriberKey** Text(100), **Month** Text(7), RecMkt, RecOps, OpenMkt, ClickMkt (Number) : par abonné et par mois, journeys MKT_ / Oxx_ (s'accumule, jamais écrasée) |
| DASH_Audience_Dist | **AsOf** Text(7), **Win** Text(2), **Contract** Text(3) (Yes/No), **RecBucket** Text(6), **Seg** Text(15), Subscribers, ReceivedMkt, ReceivedOps, OpensMkt, ClicksMkt, Months (Number) |
| DASH_Product_Map | **Source** Text(10), **Value** Text(100), **ProductGroup** Text(30) (clé primaire sur les 3 champs) : mapping des produits (email / lead `Page_Origin__c` / contrat `Product2__c`), géré depuis la page d'administration ; **nécessaire aux requêtes 02 et 04** |
| DASH_Audit_Leads / DASH_Audit_Months / DASH_Audit_Summary / DASH_Audit_Signed | facultatives, pour l'audit de l'attribution (requêtes 19 à 22, voir `sql/NOTES.md`) : LeadId (PK) ; Metric + Month (PK) ; Month + Reason (PK) ; LeadId (PK) |
| DASH_Contact_Geo | **PostalCode** Text(10), Contacts (Number), WithContract (Number : dont contacts avec un contrat Active ou Future), AsOf Text(10) : nombre de contacts par code postal (indication seule, sans lien avec les envois) ; écrasée chaque jour |

> **Leads et contrats** : les leads (SubscriberKey / Id commençant par `00QP`) sont exclus de la base abonnés et de la géographie (pas des KPI journeys ni des conversions). « Avec contrat » = au moins une ligne de `Contract_Salesforce_1` avec `Contact__c` = SubscriberKey et `Status__c` = `Active` ou `Future`. Si vous aviez déjà créé `DASH_Audience_Dist`, **recréez-la** (la clé inclut maintenant `Contract`) et ajoutez `WithContract` à `DASH_Contact_Geo`.
| DASH_Admin_Log (facultative) | **LogId** Text(40), Ts Text(25), AdminIP Text(50), Action Text(30), Target Text(100), Detail Text(200) : journal des modifications faites depuis la page d'administration |
| DASH_SMS_Monthly | **JourneyName** Text(200), **Month** Text(7), **AssetName** Text(200), Sent, **Messages**, UniqueRecipients, Delivered, Bounced (Number) |
| DASH_Config | **ConfigKey** Text(50), Value Text(200) → voir « Configuration (DE DASH_Config) » ci-dessous |
| DASH_IP_Allowlist | **IPAddress** Text(50), Description Text(200) → une ligne par IP (`203.0.113.7`) ou plage IPv4 CIDR (`203.0.113.0/24`) ; IPv6 en correspondance exacte |

## Configuration (DE DASH_Config) : plus rien à modifier dans les fichiers
Tous les réglages sont des lignes de la DE `DASH_Config` (colonnes `ConfigKey` et `Value`, Text). Les fichiers `cloudpage_api.html` et `cloudpage_dashboard.html` se collent tels quels, à chaque mise à jour, sans rien retaper. Une ligne absente = valeur par défaut.

| ConfigKey | Exemple de Value | Défaut | Rôle |
|---|---|---|---|
| `token` | `k7Xp92QmZ4aTr8LwB3` | **obligatoire** | clé secrète : le dashboard s'ouvre avec `?k=<token>` |
| `admin_token` | une clé de 24 caractères ou plus | – | clé de la page d'administration (sans cette ligne, la page n'écrit rien) |
| `admin_log_de` | `DASH_Admin_Log` | `DASH_Admin_Log` | Customer Key de la DE du journal des modifications (facultative) |
| `api_url` | `https://xxxx.pub.sfmc-content.com/abcdef` | **obligatoire** | URL publiée de la CloudPage API (celle de `cloudpage_api.html`) |
| `ip_de_key` | `DASH_IP_Allowlist` | `DASH_IP_Allowlist` | Customer Key de la DE des IP autorisées |
| `ip_de_name` | `DASH_IP_Allowlist` | = `ip_de_key` | nom de cette DE |
| `link_de_name` | `DASH_Link_Monthly` | `DASH_Link_Monthly` | nom de la DE des liens (lecture rapide) |
| `link_de_key` | `DASH_Link_Monthly` | = `link_de_name` | Customer Key de cette DE (repli) |
| `link_budget_ms` | `20000` | `20000` | temps maximum de lecture des liens avant résultat partiel |
| `asset_strip_extra` | `Preview;Test` | – | textes supplémentaires retirés des noms d'e-mails / assets, séparés par `;` (en plus des règles intégrées ci-dessous) |
| `audience_dist_de` | `DASH_Audience_Dist` | `DASH_Audience_Dist` | Customer Key de la DE de répartition des abonnés |
| `contact_geo_de` | `DASH_Contact_Geo` | `DASH_Contact_Geo` | Customer Key de la DE de géographie des contacts |
| `alert_drop_pct` | `15` | `15` | baisse de volume (en %) qui déclenche une alerte |
| `alert_min_sends` | `500` | `500` | envois du mois précédent au-dessus desquels une journey est surveillée |
| `alert_min_days` | `3` | `3` | jours complets nécessaires avant de comparer les volumes |
| `label_type_<CODE>` | `Promotional` | – | libellé affiché pour un type de campagne, ex. ligne `label_type_PROMO` |
| `label_product_<CODE>` | `Car` | – | libellé d'un produit, ex. ligne `label_product_CAR` |

Exemple de contenu :

| ConfigKey | Value |
|---|---|
| token | k7Xp92QmZ4aTr8LwB3 |
| api_url | https://xxxx.pub.sfmc-content.com/abcdef |
| label_type_PROMO | Promotional |
| label_product_CAR | Car |

- `ConfigKey` est insensible à la casse. Le token ne quitte jamais le serveur (il n'est pas transmis au navigateur).
- Seule contrainte fixe : la DE doit s'appeler **DASH_Config** (nom et Customer Key). Les erreurs de lecture apparaissent dans la ligne `Diagnostic` de la page « Access denied ».
- Le dashboard s'ouvre avec : `https://.../dashboard?k=<token>`. Sans `?k=` ou avec une autre valeur, l'API répond `unauthorized`.
- Pour changer le secret : modifiez la ligne `token`, puis mettez à jour le lien enregistré dans vos favoris.

## Automation Studio (quotidienne)
1. SQL `sql/01_journey_kpi_monthly.sql` → DASH_Journey_KPI_Monthly, **Update**
2. SQL `sql/02_conversions.sql` → DASH_Conversions, **Update** (nécessite la DE synchro `Lead_Salesforce_1`)
3. SQL `sql/06_email_kpi_monthly.sql` → DASH_Email_KPI_Monthly, **Update**
4. SQL `sql/08_link_clicks_monthly.sql` → DASH_Link_Monthly, **Update**
5. SQL `sql/10_domain_monthly.sql` → DASH_Domain_Monthly, **Update**
6. SQL `sql/13_sms_monthly.sql` → DASH_SMS_Monthly, **Update** (backfill : `sql/14_backfill_sms.sql`)
7. SQL `sql/15_sub_monthly.sql` → DASH_Sub_Monthly, **Update** (backfill : `sql/16_backfill_sub_monthly.sql`)
8. SQL `sql/17_audience_dist.sql` → DASH_Audience_Dist, **Update** (à placer **après** l'étape 7 dans l'automation ; une exécution par jour suffit)
9. SQL `sql/18_audience_geo.sql` → DASH_Contact_Geo, mode **Overwrite** (indépendante des étapes précédentes : elle ne lit que `Contact_Salesforce_1`)

Premier chargement (backfill depuis le 01/06/2026) : lancer **une fois** `sql/03_backfill_kpi.sql`, `04_backfill_conversions.sql`, `07_backfill_email_kpi.sql`, `09_backfill_link_clicks.sql` et `11_backfill_domain.sql` (Run Once, mêmes DE cibles, mode Update), puis activer les requêtes récurrentes 01 et 02. Si le timeout de 30 min est atteint, chaque fichier contient un tableau de dates pour découper le chargement mois par mois. Les fichiers SQL des automations ne contiennent aucun commentaire (Automation Studio les refuse parfois) : voir `sql/NOTES.md`. `sql/00_diagnostics.sql` sert à comprendre un résultat vide.

## CloudPages
1. Page API : coller `cloudpage_api.html` (rien à modifier) → noter l'URL publiée.
   (Facultatif) Page d'administration : coller `cloudpage_admin.html` dans une troisième CloudPage (voir « Page d'administration »).
2. Page dashboard : coller `cloudpage_dashboard.html` (rien à modifier) et ajouter l'URL de la page API dans `DASH_Config`, ligne `api_url`.
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
- **Journeys** : triées de la plus récente à la plus ancienne ; colonnes Campaign, Month (mois couvert), Family, Type, Product ; chaque journey a une icône flèche qui affiche ou masque, juste en dessous, le détail par activité email (boutons *Expand all* / *Collapse all*).
- **Categories** : vue par préfixe, type de campagne ou produit.
- **Conversions (leads)** : leads attribués (voir `sql/NOTES.md` pour les règles) ; même détail par activité email, repliable sous chaque journey.
- **Journey analysis** : une journey en détail : langues FR/NL, emails, KPI et liste des liens (chargée à la demande).
- **Insights** : trois vues.
  - *Deliverability* : top 5 des domaines (envois, bounces, complaints) et top 5 des journeys par bounces.
  - *Subscriber base* : base d'abonnés actifs, nombre d'e-mails marketing et opérationnels reçus sur les 3, 6 ou 12 mois complets précédents, et engagement (clic, ouverture sans clic, aucun) par volume reçu.
  - *Geography* : simple indication de la répartition des **contacts** (`MailingPostalCode` de `Contact_Salesforce_1`) sur une carte de la Belgique, par province ou par code postal. Elle ne reflète ni les envois ni l'engagement.
- **Alerts** : volume du mois en cours comparé au mois précédent (ramené au prorata des jours écoulés) ; alerte si plus de 15 % en dessous, pour les journeys de plus de 500 envois le mois dernier. Réglages `ALERT_DROP`, `ALERT_MIN`, `ALERT_MIN_DAYS` en haut du script du dashboard.
- **SMS** : par journey et asset (DASH_SMS_Monthly, requêtes 13 et 14).

L'API (`cloudpage_api.html`) renvoie les données principales par défaut ; `&part=links` et `&part=sms` sont chargés à la demande.

## Convention de nommage des emails (activités)
`MKT|Oxx_Type_Produit_Campagne[-info]_FR|NL_EMx_mmyyyy|ongoing`. Le split par activité ignore la langue, `EMx`, la période et tout ce qui suit un `-` dans le nom de campagne. Avant tout regroupement, les mentions `-vxx-xx` (version), `-xx-xx`, `-PDF` et `Website` sont retirées du nom, de sorte que les e-mails identiques sont regroupés (activités des journeys, onglet Journey analysis, liens, SMS). D'autres textes peuvent être ajoutés via la ligne `asset_strip_extra` de `DASH_Config`. BIKE devient BIK. Pour les produits PET et HOM, le détail cat/dog ou renters/owner est lu dans le nom.

## Accessibilité et confort (audit)
- Contrastes corrigés (thème sombre, bordures des champs, onglets) ; séries des graphiques distinguées par la forme et le style de trait ; axe de droite pour CTR % et Bounce % ; texte alternatif sur chaque graphique.
- Clavier : en-têtes de colonnes triables (boutons, `aria-sort`), onglets avec flèches / Début / Fin, lien « Skip to the data », focus conservé après un tri ou un dépliage.
- États : chargement et erreurs annoncés (`role=status` / `role=alert`), message lisible avec bouton *Retry* (le détail technique reste affiché en petit).
- Confort laptop : première colonne figée, bouton *Rates only* (colonnes de taux seulement), résumé des filtres avec nombre de lignes, bouton *Reset filters*, cartes KPI avec écart par rapport à la période précédente de même durée (flèche et couleur), nom de journey cliquable vers *Journey analysis*.
- Les filtres, l'onglet et le mode *Rates only* sont conservés dans l'adresse (après le `#`), ce qui permet de partager une vue. Le token `?k=` reste dans la partie avant le `#`.
- Hors périmètre : l'affichage mobile n'a pas été optimisé (usage prévu sur laptop).

## Base abonnés et carte (Insights)
- **Historique** : les Data Views ne gardent qu'environ 6 mois. `DASH_Sub_Monthly` garde, pour chaque abonné et chaque mois, le nombre d'e-mails reçus et l'engagement ; elle s'accumule donc mois après mois et la fenêtre de 12 mois se complète avec le temps. Le dashboard indique « Only X of the previous 12 months of history are available » tant qu'elle n'est pas complète.
- **Chargement initial** : `sql/16_backfill_sub_monthly.sql` (une fois, depuis le 01/06/2026), puis l'automation quotidienne.
- **Carte** : données incluses dans `cloudpage_dashboard.html` (contours des provinces simplifiés et position de chaque code postal belge, 51 Ko). Sources : GeoNames (CC BY 4.0) et Natural Earth (domaine public). Pour les régénérer : `python3 tools/build_geo.py && python3 tools/inject_geo.py`.
- **Géographie** : uniquement le nombre de contacts de `Contact_Salesforce_1` par code postal (4 chiffres belges ; les codes étrangers, vides ou mal formés sont comptés « sans code postal utilisable »). Aucune jointure avec les abonnés ni avec les envois. La sonde P9 de `sql/12_probes.sql` montre les formats réels des codes postaux.

## Page d'administration (cloudpage_admin.html)
Une CloudPage séparée pour gérer sans passer par Contact Builder. Elle est organisée en **trois onglets** (l'onglet ouvert est conservé dans l'adresse) :
- *IP allowlist* : la **liste des IP autorisées** (`DASH_IP_Allowlist`) : ajouter une adresse IPv4, une plage IPv4 (CIDR) ou une IPv6 avec une description, ou supprimer une entrée ;
- *Settings* : les **réglages** de `DASH_Config` (URL de l'API, noms des DE, seuils d'alerte, textes retirés des noms d'assets, token du dashboard, clé d'administration) regroupés en sections repliables (clés d'accès, réglages du dashboard, noms des DE en mode avancé), avec un filtre, la valeur par défaut affichée, un repère « custom » sur les valeurs personnalisées et un bouton *Reset* ;
- *Friendly labels* : les **libellés** des types de campagne et des produits (lignes `label_type_<CODE>` / `label_product_<CODE>`).

**Mise en route** (une seule fois) : créer la CloudPage, y coller le fichier, puis ajouter à la main dans `DASH_Config` la ligne `admin_token` (une clé secrète de 24 caractères ou plus, lettres et chiffres). La page s'ouvre avec `https://.../admin?k=<admin_token>`. Sans cette ligne, elle reste en lecture seule et l'indique.

**Sécurité**
- L'accès exige à la fois une **IP autorisée** et la **clé d'administration** (différente du token du dashboard).
- Les valeurs de `token` et `admin_token` ne sont **jamais** renvoyées au navigateur ni écrites dans le journal ; la page permet seulement de les remplacer (bouton *Generate* pour créer une clé aléatoire).
- Seuls les réglages connus sont modifiables ; chaque valeur est validée (https pour l'URL de l'API, nombres dans des bornes, noms de DE sans caractères spéciaux…).
- Garde-fous anti-verrouillage : on ne peut pas supprimer l'entrée qui autorise sa propre IP, ni pointer `ip_de_key` vers une DE illisible ou qui ne contient pas sa propre IP. `token`, `admin_token` et `api_url` ne peuvent pas être supprimés depuis la page.
- Chaque écriture est vérifiée par une relecture de la DE. Chaque modification est journalisée dans `DASH_Admin_Log` si cette DE existe.
- Recommandation : ajoutez à la liste d'IP uniquement les adresses des administrateurs qui ouvrent cette page.

### Compatibilité navigateurs et lisibilité
Testée dans Chromium (Edge, Chrome) et WebKit (Safari). Les listes déroulantes ont la même hauteur et la même flèche partout (la liste ouverte reste celle du système, non personnalisable). Les tableaux plus larges que l'écran affichent un dégradé et l'indication « scroll → » ; la première colonne reste figée. Pendant le chargement, des cartes « squelette » s'affichent.

### Noms de liens et mapping des produits (page d'administration)
- Onglet **Link names** : règles « motif d'adresse = nom ». Tout lien dont l'adresse (sans paramètres) contient le motif (`*` = joker) prend ce nom dans Journey analysis, ex. `view.belfiusdirect.be` = ReadOnline, `belfiusdirect.be/*/contactus` = ContactUs. Le motif le plus long l'emporte. Les règles sont stockées dans `DASH_Config` (clés `linkmap_001`, ...) et s'appliquent immédiatement (pas de requête à relancer).
- Onglet **Product mapping** : relie le produit du nom de l'email, `Page_Origin__c` du lead et `Product2__c` du contrat par un groupe de produits commun (DE `DASH_Product_Map`). Créez la DE, puis cliquez sur « Add the default mapping ». Les requêtes 02 et 04 lisent ce mapping à leur prochain passage ; relancez 04 (backfill) pour recalculer l'historique.
