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
- Journeys retenues : MKT_XSELL_, MKT_PROMO_, MKT_NEWS_, ODO_, OCL_, ODD_OFF_, OCX_XSELL_.
- Statuts retenus : Incomplete (uniquement journey ODO_BANK_CAR_DropOut), Viewed Premium, Offer Incomplete, Offer Viewed, Offer Created (uniquement ODD_OFF_), Signing, et Signed (converti). Les autres statuts sont ignorés.
- Produit du lead (`Page_Origin__c`) : PET = PET, VEH_V2 = CAR, VEH_MO = MOT, HOM = renters, OWNER = owner, FEM = FAM, ASS = ASS, valeur contenant ukp = FUN, autre = OTHER.
- Un lead n'est attribué à une journey que si le produit de la journey (3e segment du nom, BIKE devient BIK) est ALL, égal au produit du lead, VEH pour un lead CAR ou MOT, ou HOM pour un lead renters / owner (si le nom de la journey contient owner ou renter, seul ce type est retenu).
- Attribution last touch : le dernier envoi éligible dans les 30 jours avant la création du lead.
- Sorties en plus : Product, LeadProduct, EmailName (email du dernier envoi, pour le split par activité).

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
Voir la section « Page d'administration » du README. La page écrit dans `DASH_IP_Allowlist` et `DASH_Config` (par WSProxy, avec repli sur `UpsertData` / `DeleteData` par nom de DE) et vérifie chaque écriture par relecture. Les champs lus sont `IPAddress` / `Description` et `ConfigKey` / `Value`.
