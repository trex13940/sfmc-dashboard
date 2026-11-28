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

## Fichiers et ordre d'exécution

| Fichier | Rôle | DE cible (mode Update) | Fréquence |
|---|---|---|---|
| 01_journey_kpi_monthly.sql | KPI par journey et par mois | DASH_Journey_KPI_Monthly | quotidienne |
| 02_conversions.sql | Leads attribués (last touch) | DASH_Conversions | quotidienne |
| 06_email_kpi_monthly.sql | KPI par email (activité) | DASH_Email_KPI_Monthly | quotidienne |
| 08_link_clicks_monthly.sql | Clics par lien | DASH_Link_Monthly | quotidienne |
| 10_domain_monthly.sql | Envois / bounces / complaints par domaine | DASH_Domain_Monthly | quotidienne |
| 13_sms_monthly.sql | SMS par journey et asset | DASH_SMS_Monthly | quotidienne |
| 03, 04, 07, 09, 11, 14 | Backfill depuis le 01/06/2026 (même cibles) | idem | une seule fois |
| 00, 05, 12 | Diagnostics et sondes (Query Studio uniquement) | – | à la demande |

Tous les fichiers des automations sont **sans commentaire** (Automation Studio les refuse parfois).

## Dates des backfills (03, 04, 07, 09, 11, 14)
Dates en CST (heure des Data Views), au format `AAAAMMJJ hh:mm:ss`. Par défaut du 01/06/2026 00:00 CEST (= 31/05/2026 16:00 CST) à fin novembre. En cas de timeout (30 min), lancer plusieurs fois en changeant les deux dates du `WHERE s.EventDate` (envois) :

| Mois belge | >= | < |
|---|---|---|
| Juin 2026 | 20260531 16:00:00 | 20260630 16:00:00 |
| Juillet | 20260630 16:00:00 | 20260731 16:00:00 |
| Août | 20260731 16:00:00 | 20260831 16:00:00 |
| Septembre | 20260831 16:00:00 | 20260930 16:00:00 |
| Octobre | 20260930 16:00:00 | 20261031 17:00:00 |
| Novembre | 20261031 17:00:00 | 20261130 17:00:00 |
| Décembre | 20261130 17:00:00 | 20261231 17:00:00 |

Pour 04 (conversions), découper par date de création du lead : changer `CreatedDate >= ... AND CreatedDate < ...` avec les mêmes bornes, et l'envoi minimum `s.EventDate >= ...` = borne basse moins ~31 jours.

## Liens (08 et 09)
- Un lien sans nom (`LinkName` vide) dont l URL contient `view.belfiusdirect.be` est renommé **ReadOnline**.
- Quand `LinkContent` (ou `LinkName`) est une URL (`http…`), tout ce qui suit `?` ou `#` est supprimé : les liens qui ne diffèrent que par leurs paramètres sont regroupés (moins de lignes dans la DE). Le texte qui n est pas une URL reste inchangé. La page applique la même règle à l affichage, y compris sur les données déjà chargées.
- La clé `RowKey` contient le nom du lien : si vous relancez le backfill après un de ces changements (renommage ReadOnline ou suppression des paramètres), utilisez le mode **Overwrite** sur `DASH_Link_Monthly` (une seule fois) pour ne pas garder les anciennes lignes à nom vide ; les passages quotidiens restent en **Update**.
- L API charge les liens **une journey et une période à la fois** (`&part=links&j=<journey>&from=yyyy-mm&to=yyyy-mm`), mois par mois avec `LookupRows` (rapide), les mois les plus récents d abord, avec un budget de 20 s : au-delà, la page affiche un résultat partiel et le dit, plutôt qu une erreur 408.
- Si le DE contient beaucoup de lignes, **recréez `DASH_Link_Monthly` avec une clé primaire composée dans cet ordre : `JourneyName`, `Month`, `RowKey`** (les autres champs inchangés). Les champs de clé sont indexés : filtrer sur `JourneyName` et `Month` devient quasi instantané. Rechargez ensuite avec le backfill `09` (Overwrite).
- Réglages dans la DE `DASH_Config` : `link_de_name` (nom de la DE, pour `LookupRows`), `link_de_key` (Customer Key, pour le repli) et `link_budget_ms`.

## Conversions : règles métier (02 et 04)
Approche « leads d'abord » : la requête part de **tous** les leads de `Lead_Salesforce_1` créés dans la période (tous statuts, avec ou sans email) et les compare aux emails reçus. `DASH_Conversions` a donc **une ligne par lead**.
- Journeys comparées : MKT_XSELL_, MKT_PROMO_, MKT_NEWS_, OCX_XSELL_ (emails marketing, le lead vient après) et OCL_, ODO_, ODD_OFF_ (emails déclenchés par le lead, ils partent après sa création). Fenêtre d'origine : 30 jours avant la création (marketing) ou 30 jours après (déclenché) (un email déclenché jusqu'à 1 h avant la création est toléré, pour les décalages d'horloge).
- Produit : l'email doit avoir un groupe de produit commun avec le lead (mapping `DASH_Product_Map`, voir plus bas) ou être de produit ALL.
- **Origine du lead** (`OriginKind`, journey = `JourneyName`) : `M` = généré après un email marketing (le dernier reçu avant la création) ; sinon `T` = a déclenché un email opérationnel (le premier email OCL / ODO / ODD_OFF dans les 30 jours après la création) ; sinon `N` = aucun email trouvé, la journey est « (no email) » (pas d'adresse email, absente de `_Subscribers`, ou aucun email correspondant).
- **Conversion** : un lead `Signed` (`IsConverted = 1`) est crédité au **dernier email reçu** parmi les emails ci-dessus : `ConvJourney`, `ConvEmailName`, `ConvSendMonth`. Règles de durée : un lead est valide **70 jours** après sa création ; une offre (ODD_OFF) peut être signée jusqu'à **8 semaines (56 jours) après le premier email d'offre** (premier ODD_OFF de produit compatible reçu dans les 70 jours). La signature est donc possible jusqu'à la plus tardive des deux dates (création + 70 jours, premier email d'offre + 56 jours). La date de signature est approchée par `Lead_Salesforce_1.LastModifiedDate` : sont retenus les emails reçus de 30 jours avant la création jusqu'à `LastModifiedDate`, ou jusqu'à la fin de validité ci-dessus si `LastModifiedDate` la dépasse ou n'est pas postérieure à la création. Pour la conversion, les emails marketing reçus après la création comptent aussi (contrairement à l'origine du lead). Un lead Signed sans email est crédité à « (no email) ». Limite : un lead modifié après sa signature pour une autre raison fait reculer l'estimation de la date de signature (dans la limite de la validité).
- Autres colonnes : `DaysToLead` = nombre de jours entre l'email d'origine et la création du lead (dans un sens ou l'autre), `Opened` / `Clicked` = ouverture / clic uniques sur l'email d'origine, `Product` = produit de la journey d'origine, `LeadProduct` = groupe de produit du lead, `EmailName` = email d'origine.
- Les statuts ne servent plus de filtre : tous les statuts sont comptés (le dashboard affiche les 8 plus fréquents en colonnes).
- **Produits : mapping dans la DE `DASH_Product_Map`** (colonnes `Source`, `Value`, `ProductGroup`, clé primaire sur les trois), modifiable depuis l'onglet « Product mapping » de la page d'administration. `Source` = `LEAD` (valeur ou motif `%` appliqué à `Page_Origin__c`, ex. `%UKP%`), `EMAIL` (motif appliqué à `PRODUIT|NOMDELAJOURNEY` en majuscules ; le motif le plus long l'emporte, ex. `HOM|%OWNER%` l'emporte sur `HOM|%`) ou `CONTRACT` (valeur de `Product2__c`, utilisée par la requête 22).
- Un lead dont `Page_Origin__c` n'est pas mappé reçoit le groupe `OTHER` (il ne correspond alors qu'aux journeys ALL). **Si `DASH_Product_Map` est vide, seules les journeys ALL reçoivent des leads** : cliquez sur « Add the default mapping » dans la page d'administration avant de lancer 02 / 04. Les valeurs par défaut reproduisent les anciennes règles codées en dur et ajoutent REN = RENTERS.
- Dans une requête SQL, le nom de la DE (et non sa Customer Key) est utilisé : la DE doit s'appeler `DASH_Product_Map`.
- **Migration** : ajoutez à `DASH_Conversions` les champs `OriginKind` Text(1), `ConvJourney` Text(200), `ConvEmailName` Text(200) et `ConvSendMonth` Text(7), puis relancez `04_backfill_conversions.sql` une fois (par mois si le délai de 30 minutes est atteint). Tant que ces champs n'existent pas, le dashboard fonctionne comme avant et le signale.

## Audit de l'attribution des leads (19 à 22)
Pour valider la logique et comprendre pourquoi des leads manquent. Aucune de ces requêtes n'alimente le dashboard.
- **20** `DASH_Audit_Months` (clé Metric + Month, Overwrite) : par mois, nombre de leads créés, de leads avec email et statut suivi, de leads dont l'email est dans `_Subscribers`, d'envois dans `_Sent`, et de lignes dans `DASH_Conversions`. À lancer en premier : elle montre où la chaîne perd les leads (ex. aucun lead avant novembre dans `Lead_Salesforce_1`, ou aucun envoi avant une certaine date).
- **19** `DASH_Audit_Leads` (clé LeadId, Overwrite ; champs Text sauf SendsCandidate / SendsProductOk / SendsValid en Number) : une ligne par lead créé dans la fenêtre de dates (en tête du fichier, par défaut septembre 2026 ; une période d'un mois à la fois pour rester sous 30 minutes). `Reason` : 1 pas d'adresse email ou absente de `_Subscribers`, 2 aucun email d'une journey suivie autour de la création (de 30 jours avant à 126 jours après), 3 emails trouvés mais produit incompatible, 4 emails trouvés mais hors des règles de temps (marketing après le lead, déclenché avant lui), 8 généré après un email marketing, 9 a déclenché un email opérationnel. `SendsCandidate`, `SendsProductOk`, `SendsValid` montrent combien de candidats restent à chaque étape ; `Origin*` et `Conv*` = ce que la requête 04 attribue (mêmes règles, même mapping).
- **21** `DASH_Audit_Summary` (clé Month + Reason) : nombre de leads par mois et par raison, à partir de `DASH_Audit_Leads`.
- **22** `DASH_Audit_Signed` (clé LeadId, Overwrite) : pour les leads Signed de `DASH_Conversions`, nombre de contrats Active / Future du même email (`Contact_Salesforce_1.Email` = email du lead ; hypothèse à vérifier) et nombre dont `Product2__c` (mappé en groupe via les lignes `CONTRACT`) correspond au produit du lead.
- Les compteurs peuvent compter plusieurs fois un même envoi quand un produit appartient à plusieurs groupes (VEH = CAR et MOT).

## Colonnes et hypothèses à vérifier avec 12_probes.sql
- `_Sent.Domain` (insights domaines), `_Job.EmailName` (activités), `_Click.LinkName` / `LinkContent` (liens), `HASHBYTES` (clé de DASH_Link_Monthly).

## SMS (13 et 14)
Basées sur votre requête de reporting (quarterly) et adaptées au rythme mensuel :
- Source : `_SMSMessageTracking`. Un SMS long est stocké en plusieurs lignes (une par partie, colonne `Ordinal`) : le message est reconstitué avec `STRING_AGG(MessageText) WITHIN GROUP (ORDER BY Ordinal)`, puis **SMSCount = CEILING(longueur / 153)** (segments d un SMS concaténé).
- Un message = un abonné (`SubscriberKey`) + une activité (`JBActivityID`) + une date de création (`CreateDateTime`), comme dans votre requête.
- Activité : `JBActivityID = _JourneyActivity.ActivityID` ; le nom de la journey vient de `_Journey` (version la plus récente de l activité, pour éviter les doublons entre versions). Asset = `ActivityName`.
- **Sent** = somme des segments ; **Messages** = nombre de messages ; **UniqueRecipients** = abonnés distincts par journey, mois et asset ; **Delivered** / **Bounced** = segments des messages `Delivered = 1` / `Undelivered = 1`. Tests exclus.
- Mois en CET (la date est supposée en CST). Journeys MKT_ et Oxx_ uniquement, donc OKM_ et ODD_DOC_ aujourd hui.
- Limites : 153 caractères par segment vaut pour l alphabet GSM ; avec des caractères hors GSM (certains accents, emojis) un segment ne contient que 67 caractères, donc le total est sous-estimé. Les destinataires uniques sont distincts par mois ; sur plusieurs mois le dashboard les additionne.

## Base abonnés et géographie (15 à 18)
- **15 / 16** : `DASH_Sub_Monthly` (clé : SubscriberKey + Month). Par abonné et par mois (CET) : `RecMkt` / `RecOps` = e-mails reçus (envoyés et non bounced) des journeys MKT_ / Oxx_, `OpenMkt` / `ClickMkt` = ouvertures / clics uniques sur les e-mails marketing. Mode Update : seuls le mois courant et le précédent sont recalculés, l'historique n'est jamais écrasé.
- **17** : `DASH_Audience_Dist` (clé : AsOf, Win, Contract, RecBucket, Seg). Abonnés actifs hors leads (`SubscriberKey NOT LIKE '00QP%'`), avec `Contract` = Yes si `Contract_Salesforce_1` contient une ligne `Contact__c` = SubscriberKey et `Status__c` IN ('Active','Future'), sinon No ; répartis par fenêtre (3, 6, 12 mois complets avant le mois courant), par tranche d'e-mails marketing reçus (0, 1-2, 3-5, 6-10, 11-20, 21+) et par segment : `Clicker` (au moins 1 clic), `Opener` (au moins 1 ouverture, pas de clic), `NoEngagement` (reçu, ni ouvert ni cliqué), `NotReached` (aucun e-mail marketing reçu). `Months` = nombre de mois d historique réellement disponibles dans la fenêtre. `AsOf` = mois courant : un instantané par mois est conservé.
- **18** : `DASH_Contact_Geo` (clé : PostalCode), mode **Overwrite**. Compte les contacts de `Contact_Salesforce_1` (hors leads `00QP%`) par code postal, avec `WithContract` = nombre de ceux ayant un contrat Active ou Future, (`MailingPostalCode`, préfixes B- et BE- retirés, accepté seulement s il compte exactement 4 chiffres entre 1000 et 9999 ; sinon `N/A`). C est une **simple indication de répartition** : pas de jointure avec `_Subscribers` ni avec les envois, pas de notion d engagement ni de fenêtre de temps. `AsOf` = date du calcul (CET). Le fichier garde le nom `18_audience_geo.sql`.
- Si 17 dépasse le délai de 30 minutes sur une très grande base, me le dire pour passer à un calcul par lots (la requête 18 est légère : elle ne lit que les contacts).

## Page d'administration
Voir la section « Page d'administration » du README (page `html/cloudpage_admin.html`). La page écrit dans `DASH_IP_Allowlist` et `DASH_Config` (par WSProxy, avec repli sur `UpsertData` / `DeleteData` par nom de DE) et vérifie chaque écriture par relecture. Les champs lus sont `IPAddress` / `Description` et `ConfigKey` / `Value`.

## Listes de publication (23 à 26)
Source : les DE `List_Info` (« Information »), `List_Newsletter`, `List_Promo` et `List_Survey` (champ clé supposé `SubscriberKey`, variable `KEY` dans le générateur), plus `_Subscribers` pour « All Subscribers ». Chaque membre est compté une fois par liste ; les leads (`00QP…`) et valeurs vides sont exclus. Le statut vient de `_Subscribers` ; une clé absente de `_Subscribers` donne « Not in All Subscribers ».
- **23** `DASH_PubList_Snapshot` (clé : AsOf, ListName, Status, Contract), mode Update : membres par liste, statut et contrat actif ou futur (Yes / No). Un instantané par mois (`AsOf`) est conservé ; le dashboard compare le dernier au précédent.
- **24** et **25** `DASH_PubList_Monthly` (clé : ListName, Month), mode Update : inscriptions (`DateJoined`) et désinscriptions (`DateUnsubscribed`) par mois en CET, **All Subscribers uniquement** (les DE de listes n'ont pas de dates connues). 24 recalcule les 3 derniers mois chaque jour ; 25 est le chargement initial depuis le 01/01/2025.
- **26** sondes : `SELECT TOP 5 *` sur les 4 DE (Query Studio) et comptage de lignes / clés distinctes (cible `DASH_Debug`).
- La requête 27 (comparaison avec une DE source) n'existe plus.
- Test : la logique des requêtes 23 et 25 a été vérifiée sur une base de test (DuckDB) contre un calcul indépendant ; elles n'ont pas encore tourné dans Marketing Cloud.

## Délivrabilité : références des fournisseurs
- Complaints : `_Complaint` n'est alimentée que par les boucles de retour des fournisseurs qui en envoient (Microsoft, Yahoo). À notre connaissance Gmail n'en envoie pas : le taux de spam de Gmail se lit dans Google Postmaster Tools. Repères : Google, taux de spam sous 0,1 % et jamais 0,3 % ; Yahoo, sous 0,3 %.
- Bounces : aucun fournisseur ne publie de seuil ; repère de l'industrie, moins de 2 % au total et nettement moins de 1 % de hard bounces. `HardBounces` = nombre de lignes `_Bounce` dont `BounceCategory` commence par « Hard » (requêtes 01, 03, 10, 11) ; la sonde P10 de `12_probes.sql` liste les valeurs réelles.
- « Delivered » = accepté par le serveur destinataire (envois moins bounces), pas forcément en boîte de réception.

