# Dashboard Journeys SFMC

Tableau de bord des KPI e-mail / SMS des journeys Salesforce Marketing Cloud, sous forme de CloudPage.

**Architecture** : Data Views → (Automation Studio, SQL) → Data Extensions agrégées → CloudPage API (SSJS, JSON) → CloudPage dashboard (HTML/JS). Les DE gardent l'historique au-delà des ~6 mois de rétention des Data Views.

```
html/         les 3 CloudPages à coller dans Marketing Cloud (cloudpage_api, cloudpage_dashboard, cloudpage_admin)
sql/          requêtes d'Automation Studio (01 à 22) + NOTES.md (règles métier, diagnostics)
geo/, tools/  données et scripts de la carte de Belgique (voir « Carte »)
screenshots/  captures de chaque page, dans l'ordre d'affichage (données fictives)
```

---

## 1. Mises à jour à déployer et tester dans Marketing Cloud

Les demandes ci-dessous (faites à partir de 16 h le 27/11/2026) sont **implémentées et poussées, mais jamais exécutées dans Marketing Cloud** : elles ont été validées uniquement sur des données fictives (navigateurs Chromium et WebKit), des tests de logique SQL sur une base de test (DuckDB) et un contrôle de syntaxe T-SQL / JavaScript ES3. Les premiers essais réels peuvent donc révéler des écarts (noms de champs, performance, délais d'exécution).

### Étape A : fichiers à recoller (les 3 CloudPages, nouveaux chemins `html/`)
| Fichier | Contenu |
|---|---|
| `html/cloudpage_api.html` | API : lit les nouveaux champs de `DASH_Conversions` (repli automatique si absents) |
| `html/cloudpage_dashboard.html` | toutes les modifications du dashboard listées plus bas |
| `html/cloudpage_admin.html` | onglets *Link names* et *Product mapping*, boîtes de confirmation natives |

### Étape B : données et requêtes (dans cet ordre)
1. **Créer `DASH_Product_Map`** : `Source` Text(10), `Value` Text(100), `ProductGroup` Text(30), clé primaire sur les trois champs. Puis, dans la page d'administration, onglet *Product mapping* : bouton **« Add the default mapping »**. Sans mapping, seules les journeys au produit ALL reçoivent des leads.
2. **Ajouter à `DASH_Conversions`** (Text) : `OriginKind` (1), `ConvJourney` (200), `ConvEmailName` (200), `ConvSendMonth` (7).
3. **Vérifier que `Lead_Salesforce_1` contient le champ `LastModifiedDate`** (utilisé comme date de signature approchée).
4. **Relancer `sql/04_backfill_conversions.sql`** (Run Once, mois par mois si le délai de 30 minutes est dépassé), puis laisser tourner `sql/02_conversions.sql` dans l'automation quotidienne.
5. **Listes de publication** (nouvelle vue *Insights › Publication lists*, basée sur les DE `List_Info`, `List_Newsletter`, `List_Promo` et `List_Survey`) : créer `DASH_PubList_Snapshot` (**AsOf** Text(7), **ListName** Text(200), **Status** Text(30), **Contract** Text(3) en clé primaire ; Subscribers Number) et `DASH_PubList_Monthly` (**ListName** Text(200), **Month** Text(7) en clé primaire ; Joined, Unsubscribed Number, uniquement All Subscribers). Lancer d'abord `sql/26_probe_lists.sql` (partie A dans Query Studio : `SELECT TOP 5 *` sur les 4 DE) (le champ clé des DE s'appelle `Subscriber Key`, avec un espace, d'où `[Subscriber Key]` dans les requêtes). Puis `sql/25_backfill_publist_monthly.sql` (une fois) et `sql/23_publist_snapshot.sql` / `sql/24_publist_monthly.sql` (quotidiennes, mode Update). Ajouter les deux requêtes à l'automation.
6. **Hard bounces** : ajouter le champ `HardBounces` (Number) à `DASH_Journey_KPI_Monthly` et à `DASH_Domain_Monthly`, lancer `sql/12_probes.sql` (sonde P10) pour vérifier les valeurs de `BounceCategory` dans `_Bounce` (les requêtes comptent les catégories qui commencent par « Hard »), puis relancer **une fois** `sql/03_backfill_kpi.sql` et `sql/11_backfill_domain.sql` (mode Update). Sans ce champ, le dashboard fonctionne comme avant et le signale.
7. Facultatif, pour contrôler l'attribution : `sql/20_audit_months.sql`, puis `sql/19_audit_lead_attribution.sql` (un mois à la fois), `21` et `22` (DE cibles décrites dans `sql/NOTES.md`).

### Étape C : ce qui a changé et ce qu'il faut tester
| # | Modification | À tester dans Marketing Cloud |
|---|---|---|
| 1 | **Page d'administration : erreur de publication** (« incomplete or incorrect MC scripting »). Le code serveur évite les séquences `/*`, `*/` et `%` dans les chaînes ; les messages d'erreur ont été reformulés. La cause exacte n'a pas pu être confirmée. | Republier `cloudpage_admin.html`. Si l'erreur revient : indiquer la page concernée ; repli possible sur la version d'avant les deux nouveaux onglets (commit `5568a65`). |
| 2 | **Admin : onglets *Link names* et *Product mapping*** (règles de noms de liens `linkmap_NNN` dans `DASH_Config`, mapping dans `DASH_Product_Map`). | Ajouter les règles `view.belfiusdirect.be` = ReadOnline et `belfiusdirect.be/*/contactus` = ContactUs ; ajouter / supprimer une ligne de mapping ; vérifier l'effet dans *Journey analysis*. |
| 3 | **Noms d'assets** : « Website » est retiré sans supprimer le `_` qui le précède (`CAR_WebsiteContinueLater` devient `CAR_ContinueLater`). | *Journey analysis* > By email : les noms ont leur langue (colonne Lang). |
| 4 | **Journey analysis : sélecteur de journey avec recherche**, aucune journey présélectionnée (page vide tant qu'aucune n'est choisie). Liens groupés par email, sans colonne Lang. | Ouvrir l'onglet directement : seul le message s'affiche ; taper quelques mots, choisir avec le clavier ; ouvrir une journey depuis l'onglet Journeys. |
| 5 | **Leads « leads d'abord »** : tous les leads sont comparés aux emails reçus (marketing avant le lead, opérationnels OCL / ODO / ODD_OFF après), conversions créditées au dernier email reçu avant `LastModifiedDate`, validité du lead 70 jours et offres ODD_OFF signables 8 semaines après le premier email d'offre. | Onglet *Conversions* : cartes (leads, signés, taux, après un email marketing, déclenchés, sans email), ligne « (no email) », colonnes « Signed (these leads) » et « Conversions credited ». Comparer avec les résultats de `19_audit_lead_attribution.sql`. Vérifier le nombre de leads d'avant novembre. |
| 6 | **Colonnes Type et Product** : libellé seul (le code est dans l'infobulle). | Définir quelques libellés (onglet *Friendly labels*) et vérifier les tableaux. |
| 7 | **Insights** : les boutons Deliverability / Subscriber base / Geography sont toujours tout en haut. | Parcourir les trois vues. |
| 8 | **Geography** : correction des bulles trop grandes en vue « % with contract » (codes postaux), couleur relative à la moyenne, valeur écrite sur chaque province. | Vues Provinces et Postal codes, avec « Contacts » et « % with contract ». |
| 9 | **Bonnes pratiques web** : confirmations de la page admin dans une boîte de dialogue native, ombre de défilement des tableaux en CSS pur, thèmes clair / sombre déclarés, zones de tableau accessibles au clavier, annonce du tri. | Supprimer une ligne dans la page admin (Échap annule) ; tableaux larges (ombre à droite, Tab puis flèches) ; thème sombre. |
| 10 | **Revue de design** : ligne de contexte sous les filtres (période et filtres appliqués), valeurs des cartes en couleur neutre, 4 cartes KPI principales et les autres en bandeau discret, Deliverability en grille 2 × 2, **tableaux en mode « ratios » par défaut** (bouton « All columns » pour les volumes). | Vérifier la ligne de contexte sur chaque onglet ; les liens enregistrés avant cette version ouvrent le mode ratios. |
| 11 | **Sélecteur de période** : une seule liste remplace *From / To* (voir la liste ci-dessous). La période choisie est dans l'adresse (`per=`). | Essayer chaque période ; elle est calculée sur la date de « Data as of » (heure belge). Les anciens liens avec `from=` / `to=` sont ignorés (retour à « All periods »). |
| 12 | **Journey analysis : comparaison de deux journeys** (liste « Compare with »). Tableau de 9 indicateurs côte à côte avec la différence, graphique d'engagement, détail de la journey A en dessous ; la comparaison est dans l'adresse (`j2=`). | Comparer deux journeys (ex. Newsletter Q2 et Q3) sur une période ; vérifier les totaux avec l'onglet Journeys. |
| 13 | **Insights › Publication lists** : membres actifs de chaque liste (DE `List_Info`, `List_Newsletter`, `List_Promo`, `List_Survey`) avec ou sans contrat, désinscrits, bounced / held, évolution par rapport à l'instantané du mois précédent ; inscriptions / désinscriptions par mois pour All Subscribers. Nouvelles DE et requêtes 23 à 26 (étape B, point 5). | Voir la section « Listes de publication : à confirmer » ci-dessous. |
| 14 | **Recommandations** : nouvel onglet *Recommendations* (entre Insights et Alerts). 13 contrôles calculés sur les données déjà chargées : bounce par journey et par domaine, plaintes, baisse du taux de livraison, ouverture et clic sous la médiane des journeys semblables, baisse par rapport à la période précédente, écart FR / NL, emails faibles dans une journey, leads qui ne signent pas, leads sans email, comparaison des origines, abonnés avec contrat non joints, fatigue selon la fréquence, listes qui perdent des abonnés, provinces sous-couvertes. Seuils réglables dans la page admin (*Settings* : `reco_min_sends`, `reco_min_leads`, `reco_gap_pt`). | Vérifier que les constats sont cohérents avec ce que vous connaissez des journeys, ajuster les seuils, regarder la liste « Checks not run » (données manquantes) et le détail via « See the data ». |
| 15 | **Délivrabilité alignée sur Google, Yahoo et Microsoft** : plaintes à deux niveaux (« Watch » dès 0,1 %, « Fix » dès 0,3 %, repères de Google et Yahoo), bounces séparés en hard et soft (« Watch » dès 1 % de hard bounces, « Fix » dès 2 %), rappel que Gmail ne remonte pas ses plaintes (Postmaster Tools), tableau « chiffres contre références » et encadré des exigences (SPF / DKIM / DMARC, désinscription en un clic) dans *Insights › Deliverability*, ouvertures jugées avec prudence (protection de la vie privée) : un écart d'ouverture n'est « Fix » que si les clics le confirment. | Exécuter la sonde P10 ; vérifier que `HardBounces` se remplit ; comparer la ligne « Complaint rate » avec Google Postmaster Tools. |

**Périodes proposées** : All periods, This month, Previous month, Last 2 months, Last 3 months, This quarter, Previous quarter, Last 6 months, This half-year, Previous half-year, Last 12 months, This year, Previous year. Chaque entrée affiche entre parenthèses les mois couverts.

### Listes de publication : à confirmer
Les requêtes 23 à 25 lisent directement les DE `List_Info` (affichée « Information »), `List_Newsletter`, `List_Promo` et `List_Survey`, et le statut de chaque membre est lu dans `_Subscribers` (clé inconnue = « Not in All Subscribers »). Pour finaliser, j'ai besoin de :
1. le résultat de `SELECT TOP 5 *` sur les 4 DE (`26_probe_lists.sql`, partie A) : les éventuelles colonnes de statut ou de date ;
2. si les DE ont des colonnes de date d'inscription / désinscription, les inscrits et désinscrits par mois pourront être ajoutés pour chaque liste (pour l'instant, seul All Subscribers les a ; les autres affichent « – »).
Sans dates, l'historique se construit avec un instantané par mois : la colonne « Active vs mois précédent » apparaît dès le 2ᵉ instantané.
### Rappels de sécurité
- Le token du dashboard a été collé dans une conversation : **changez-le** (page admin, onglet *Settings*).
- Si une plage d'IP temporaire a été ajoutée pour une revue (`160.79.106.0/24`), **retirez-la** de `DASH_IP_Allowlist`.

---

## 2. Mise en place

### Data Extensions à créer
| DE | Champs (PK en gras) |
|---|---|
| DASH_Journey_KPI_Monthly | **JourneyName** Text(200), **Month** Text(7), Category Text(3), Sends, Bounces, HardBounces, Opens, UniqueClicks, Unsubscribes, Complaints (Number) |
| DASH_Conversions | **LeadId** Text(18) ; une ligne par lead : JourneyName Text(200) (journey d'origine ou « (no email) »), Category Text(50), SendMonth Text(7), SendDate Text(50), LeadCreatedDate Text(50), LeadStatus Text(100), Product Text(20), LeadProduct Text(20), EmailName Text(200), OriginKind Text(1), ConvJourney Text(200), ConvEmailName Text(200), ConvSendMonth Text(7), IsConverted, DaysToLead, Opened, Clicked (Number) |
| DASH_Email_KPI_Monthly | **JourneyName** Text(200), **Month** Text(7), **EmailName** Text(200), Sends, Bounces, Opens, UniqueClicks, Unsubscribes, Complaints (Number) |
| DASH_Link_Monthly | **JourneyName** Text(200), **Month** Text(7), **RowKey** Text(32) (clé primaire composée dans cet ordre, pour des lectures rapides), EmailName Text(200), LinkName Text(300), LinkContent Text(300), UniqueClicks, TotalClicks (Number) |
| DASH_Domain_Monthly | **Domain** Text(100), **Month** Text(7), Sends, Bounces, HardBounces, Complaints (Number) |
| DASH_SMS_Monthly | **JourneyName** Text(200), **Month** Text(7), **AssetName** Text(200), Sent, Messages, UniqueRecipients, Delivered, Bounced (Number) |
| DASH_Sub_Monthly | **SubscriberKey** Text(100), **Month** Text(7), RecMkt, RecOps, OpenMkt, ClickMkt (Number) : par abonné et par mois, journeys MKT_ / Oxx_ (s'accumule, jamais écrasée) |
| DASH_Audience_Dist | **AsOf** Text(7), **Win** Text(2), **Contract** Text(3) (Yes/No), **RecBucket** Text(6), **Seg** Text(15), Subscribers, ReceivedMkt, ReceivedOps, OpensMkt, ClicksMkt, Months (Number) |
| DASH_PubList_Snapshot | **AsOf** Text(7), **ListName** Text(200), **Status** Text(30), **Contract** Text(3) (clé primaire sur les 4 champs), Subscribers (Number) : membres par liste (Information, Newsletter, Promo, Survey, All Subscribers), statut lu dans `_Subscribers`, avec ou sans contrat actif ou futur ; un instantané par mois |
| DASH_PubList_Monthly | **ListName** Text(200), **Month** Text(7), Joined, Unsubscribed (Number) : inscriptions et désinscriptions par mois, All Subscribers uniquement (s'accumule) |
| DASH_Contact_Geo | **PostalCode** Text(10), Contacts (Number), WithContract (Number), AsOf Text(10) : contacts par code postal (indication seule) ; écrasée chaque jour |
| DASH_Product_Map | **Source** Text(10), **Value** Text(100), **ProductGroup** Text(30) (clé primaire sur les 3 champs) : mapping des produits (email / lead `Page_Origin__c` / contrat `Product2__c`), géré depuis la page d'administration ; **nécessaire aux requêtes 02 et 04** |
| DASH_Config | **ConfigKey** Text(50), Value Text(200) : voir « Configuration » |
| DASH_IP_Allowlist | **IPAddress** Text(50), Description Text(200) : une ligne par IP (`203.0.113.7`) ou plage IPv4 CIDR (`203.0.113.0/24`) ; IPv6 en correspondance exacte |
| DASH_Admin_Log (facultative) | **LogId** Text(40), Ts Text(25), AdminIP Text(50), Action Text(30), Target Text(100), Detail Text(200) : journal des modifications faites depuis la page d'administration |
| DASH_Audit_Leads / _Months / _Summary / _Signed (facultatives) | audit de l'attribution des leads (requêtes 19 à 22, voir `sql/NOTES.md`) : LeadId (PK) ; Metric + Month (PK) ; Month + Reason (PK) ; LeadId (PK) |

> **Leads et contrats** : les leads (SubscriberKey / Id commençant par `00QP`) sont exclus de la base abonnés et de la géographie (pas des KPI journeys ni des conversions). « Avec contrat » = au moins une ligne de `Contract_Salesforce_1` avec `Contact__c` = SubscriberKey et `Status__c` = `Active` ou `Future`.

### Configuration (DE `DASH_Config`) : plus rien à modifier dans les fichiers HTML
Tous les réglages sont des lignes de la DE `DASH_Config` (colonnes `ConfigKey` et `Value`, Text), modifiables depuis la page d'administration. Les fichiers de `html/` se collent tels quels. Une ligne absente = valeur par défaut. `ConfigKey` est insensible à la casse.

| ConfigKey | Exemple | Défaut | Rôle |
|---|---|---|---|
| `token` | `k7Xp92QmZ4aTr8LwB3` | **obligatoire** | clé secrète : le dashboard s'ouvre avec `?k=<token>` (jamais transmise au navigateur) |
| `admin_token` | 24 caractères ou plus | – | clé de la page d'administration (sans cette ligne, elle n'écrit rien) |
| `api_url` | `https://xxxx.pub.sfmc-content.com/abcdef` | **obligatoire** | URL publiée de la CloudPage API |
| `ip_de_key` / `ip_de_name` | `DASH_IP_Allowlist` | idem | Customer Key et nom de la DE des IP autorisées |
| `link_de_name` / `link_de_key` | `DASH_Link_Monthly` | idem | DE des liens (lecture rapide / repli) |
| `link_budget_ms` | `20000` | `20000` | temps maximum de lecture des liens avant résultat partiel |
| `audience_dist_de` / `contact_geo_de` | `DASH_Audience_Dist` / `DASH_Contact_Geo` | idem | DE de la base abonnés et de la géographie |
| `publist_snapshot_de` / `publist_monthly_de` | `DASH_PubList_Snapshot` / `DASH_PubList_Monthly` | idem | DE des listes de publication |
| `product_map_de` / `product_map_name` | `DASH_Product_Map` | idem | DE du mapping des produits |
| `admin_log_de` | `DASH_Admin_Log` | idem | DE du journal des modifications (facultative) |
| `asset_strip_extra` | `Preview;Test` | – | textes supplémentaires retirés des noms d'e-mails / assets, séparés par `;` |
| `alert_drop_pct` / `alert_min_sends` / `alert_min_days` | `15` / `500` / `3` | idem | seuils des alertes de volume |
| `reco_min_sends` / `reco_min_leads` / `reco_gap_pt` | `1000` / `30` / `5` | idem | onglet Recommendations : volume minimum d'emails délivrés, nombre minimum de leads, écart en points qui déclenche une recommandation |
| `label_type_<CODE>` / `label_product_<CODE>` | `Promotional` / `Car` | – | libellés lisibles (ex. `label_type_PROMO`) |
| `linkmap_<NNN>` | `view.belfiusdirect.be => ReadOnline` | – | règles de noms de liens (gérées par l'onglet *Link names*) |

La DE doit s'appeler **DASH_Config** (nom et Customer Key). Le dashboard s'ouvre avec `https://.../dashboard?k=<token>` ; sans `?k=` correct, l'API répond `unauthorized`. Les erreurs de lecture apparaissent dans la ligne `Diagnostic` de la page « Access denied ».

### Automation Studio (quotidienne)
1. `sql/01_journey_kpi_monthly.sql` → DASH_Journey_KPI_Monthly, **Update**
2. `sql/02_conversions.sql` → DASH_Conversions, **Update** (nécessite `Lead_Salesforce_1` et `DASH_Product_Map`)
3. `sql/06_email_kpi_monthly.sql` → DASH_Email_KPI_Monthly, **Update**
4. `sql/08_link_clicks_monthly.sql` → DASH_Link_Monthly, **Update**
5. `sql/10_domain_monthly.sql` → DASH_Domain_Monthly, **Update**
6. `sql/13_sms_monthly.sql` → DASH_SMS_Monthly, **Update**
7. `sql/15_sub_monthly.sql` → DASH_Sub_Monthly, **Update**
   (listes de publication : `sql/23_publist_snapshot.sql` → DASH_PubList_Snapshot et `sql/24_publist_monthly.sql` → DASH_PubList_Monthly, **Update**, après la création des DE)
8. `sql/17_audience_dist.sql` → DASH_Audience_Dist, **Update** (après l'étape 7 ; une exécution par jour)
9. `sql/18_audience_geo.sql` → DASH_Contact_Geo, **Overwrite** (ne lit que `Contact_Salesforce_1`)

**Premier chargement** (depuis le 01/06/2026) : lancer **une fois** (Run Once, mêmes DE cibles, mode Update) `03_backfill_kpi.sql`, `04_backfill_conversions.sql`, `07_backfill_email_kpi.sql`, `09_backfill_link_clicks.sql`, `11_backfill_domain.sql`, `14_backfill_sms.sql` et `16_backfill_sub_monthly.sql`. Si le délai de 30 minutes est atteint, chaque fichier contient un tableau de dates pour découper le chargement par mois. Les fichiers SQL n'ont aucun commentaire (Automation Studio les refuse parfois) : voir `sql/NOTES.md`. `sql/00_diagnostics.sql` et `sql/12_probes.sql` aident à comprendre un résultat vide.

### CloudPages
1. **API** : coller `html/cloudpage_api.html`, publier, noter l'URL.
2. **Dashboard** : coller `html/cloudpage_dashboard.html`, puis ajouter l'URL de l'API dans `DASH_Config` (ligne `api_url`). Accès : `https://.../dashboard?k=<token>`.
3. **Administration** (facultatif) : coller `html/cloudpage_admin.html` (voir section 4).

### Contrôle d'accès (IP + token)
Les pages vérifient `Platform.Request.ClientIP` contre `DASH_IP_Allowlist` à chaque requête (fail closed : DE vide ou absente = accès refusé) ; la page de refus affiche l'IP détectée. Le token `?k=` reste exigé en plus.

### Fuseau horaire
Data Views et `GETDATE()` = CST fixe (UTC-6). Les requêtes convertissent en CET/CEST (Europe/Brussels) via `TODATETIMEOFFSET(..., '-06:00') AT TIME ZONE 'Central European Standard Time'` : mois d'envoi, dates de leads et délais sont en heure belge. « Data as of » et les périodes relatives (ce mois-ci, ce trimestre…) suivent aussi l'heure belge.

---

## 3. Le dashboard

### Barre de filtres et période
Une liste **Period** remplace les anciens *From / To*. Elle propose : toutes les périodes, ce mois-ci, le mois précédent, les 2 derniers mois, les 3 derniers mois, ce trimestre, le trimestre précédent, les 6 derniers mois, ce semestre, le semestre précédent, les 12 derniers mois, cette année, l'année précédente. Une ligne de contexte sous la barre rappelle la période et les filtres appliqués. Les filtres, l'onglet, la période et le mode d'affichage sont conservés dans l'adresse (après le `#`), ce qui permet de partager une vue.

### Onglets
- **Journeys** : triées de la plus récente à la plus ancienne ; Campaign, Month (mois couvert, ou mois d'envoi pour les journeys « ongoing »), Family, Type, Product. Chaque journey se déplie pour afficher ses emails avec leur propre type et produit. Par défaut les tableaux affichent les ratios ; le bouton *All columns* ajoute les volumes.
- **Categories** : vue par préfixe, type de campagne ou produit.
- **Conversions (leads)** : attribution « leads d'abord » (voir plus bas), même détail par activité email.
- **Journey analysis** : une journey en détail (choisie avec la liste de recherche) : langues FR/NL, emails, KPI, liens groupés par email (chargés à la demande). Une seconde liste « Compare with » compare deux journeys (tableau côte à côte, différence, graphique d'engagement).
- **Insights** : *Deliverability* (top 5 domaines et journeys, chiffres comparés aux références de Google, Yahoo et Microsoft), *Subscriber base* (3, 6 ou 12 mois précédents, avec ou sans contrat actif ou futur), *Publication lists* (abonnés, désinscrits, inscriptions et désinscriptions par liste), *Geography* (carte de Belgique par province ou code postal, contacts avec ou sans contrat).
- **Recommendations** : constats classés « Fix » (à corriger), « Watch » (à surveiller) et « Insight », par catégorie (Deliverability, Performance, Leads, Audience), chacun avec le chiffre à l'appui, une action suggérée et un lien vers les données. Une règle ne se déclenche que si le volume est suffisant ; ce sont des pistes à vérifier, pas des preuves (l'attribution des leads est une approximation et 6 mois d'historique ne montrent pas la saisonnalité).
- **Alerts** : volume du mois en cours comparé au mois précédent au prorata des jours écoulés (seuils dans `DASH_Config`).
- **SMS** : par journey et asset.

### Conventions de nommage
`MKT|Oxx_TYPE_PRODUIT_Nom de campagne_mmyyyy|ongoing` est lu côté navigateur. Pour les emails : `MKT|Oxx_Type_Produit_Campagne[-info]_FR|NL_EMx_mmyyyy|ongoing`. Avant tout regroupement, les mentions `-vxx-xx`, `-xx-xx`, `-PDF` et le texte `Website` (ainsi que `asset_strip_extra`) sont retirés pour regrouper les emails identiques. BIKE devient BIK ; pour PET et HOM, le détail cat/dog ou renters/owner est lu dans le nom. Noms non conformes → `n/a`.

### Leads : attribution « leads d'abord »
Tous les leads de `Lead_Salesforce_1` sont listés puis comparés aux emails reçus (le produit de l'email doit correspondre à celui du lead, ou être ALL) :
- **généré après un email marketing** (MKT_XSELL / PROMO / NEWS, OCX_XSELL) : dernier email reçu dans les 30 jours avant la création ;
- **a déclenché un email opérationnel** (OCL, ODO, ODD_OFF) : premier de ces emails dans les 30 jours après la création ;
- **sans email** : ligne « (no email) ».
Un lead **Signed** est crédité au **dernier email reçu avant `LastModifiedDate`**, dans la limite de validité du lead (70 jours après la création, ou 8 semaines après le premier email d'offre ODD_OFF si c'est plus tard). Détail et migration : `sql/NOTES.md`.

### Base abonnés et carte
- Les Data Views ne gardent qu'environ 6 mois : `DASH_Sub_Monthly` accumule, par abonné et par mois, les emails reçus et l'engagement ; la fenêtre de 12 mois se complète avec le temps.
- **Carte** : contours des provinces et zones des codes postaux belges, inclus dans `html/cloudpage_dashboard.html` (126 Ko ; sources GeoNames CC BY 4.0 et Natural Earth, domaine public). Les zones des codes postaux sont **approximées** : chaque zone est le territoire le plus proche de la position du code postal (diagramme de Voronoi), découpé par le contour de la Belgique ; ce ne sont pas les limites postales officielles et elles peuvent traverser une limite de province. En vue *Postal codes*, la couleur suit une échelle logarithmique (quelques zones concentrent beaucoup de contacts) et une liste « Zoom on » permet de se rapprocher d'une province. Pour de vraies limites, il faudrait un fichier de polygones des codes postaux ou des communes (par exemple des données ouvertes de Statbel ou de bpost) à brancher dans `tools/build_geo.py`. Pour régénérer : `python3 tools/build_geo.py && python3 tools/inject_geo.py`.
- **Géographie** : nombre de contacts par code postal belge à 4 chiffres (les autres sont comptés « sans code postal utilisable »), sans lien avec les envois ni l'engagement.

### Accessibilité et confort
Contrastes, séries de graphiques distinguées par la forme, texte alternatif sur les graphiques, onglets et tris au clavier (`aria-sort`), zones de tableau défilables au clavier, états de chargement / erreur annoncés, première colonne figée, cartes KPI avec écart par rapport à la période précédente de même durée, thème clair et sombre, compatibilité Chromium (Edge, Chrome) et WebKit (Safari). L'affichage mobile n'est pas optimisé (usage prévu sur laptop).

---

## 4. Page d'administration (`html/cloudpage_admin.html`)
Une CloudPage séparée, en **cinq onglets** (l'onglet ouvert est conservé dans l'adresse) :
- *IP allowlist* : ajouter ou supprimer une adresse IPv4, une plage IPv4 (CIDR) ou une IPv6 ;
- *Settings* : réglages de `DASH_Config` en sections repliables, avec valeur par défaut, repère « custom » et bouton *Reset* ;
- *Friendly labels* : libellés des types de campagne et des produits ;
- *Link names* : règles « motif d'adresse = nom » (`*` = joker, le motif le plus long l'emporte), appliquées immédiatement dans Journey analysis ;
- *Product mapping* : groupes de produits reliant le produit de l'email, `Page_Origin__c` du lead et `Product2__c` du contrat (DE `DASH_Product_Map`) ; lu par les requêtes 02 et 04.

**Mise en route** (une seule fois) : créer la CloudPage, y coller le fichier, ajouter dans `DASH_Config` la ligne `admin_token` (24 caractères ou plus). La page s'ouvre avec `https://.../admin?k=<admin_token>`.

**Sécurité** : accès réservé à une IP autorisée **et** à la clé d'administration (différente du token du dashboard) ; `token` et `admin_token` ne sont jamais renvoyés au navigateur ni journalisés ; seuls les réglages connus sont modifiables et chaque valeur est validée ; garde-fous anti-verrouillage (on ne peut pas supprimer sa propre IP ni pointer vers une DE illisible) ; chaque écriture est vérifiée par relecture et journalisée dans `DASH_Admin_Log` si elle existe ; confirmations de suppression dans une boîte de dialogue native.
