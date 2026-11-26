-- SONDES a lancer dans Query Studio, UNE a la fois (ces requetes ne servent pas aux automations).

-- P1 : colonnes de la data view SMS (envoyer-moi les noms de colonnes + 2-3 lignes)
SELECT TOP 10 * FROM _SMSMessageTracking

-- P2 : autre data view SMS (journal des abonnes)
SELECT TOP 10 * FROM _SMSSubscriberLog

-- P3 : types d activites de journey (pour reperer les activites SMS)
SELECT ActivityType, COUNT(*) AS N FROM _JourneyActivity GROUP BY ActivityType ORDER BY COUNT(*) DESC

-- P4 : valeurs reelles de Page_Origin__c (verifier le mapping produit des leads)
SELECT Page_Origin__c, COUNT(*) AS N FROM Lead_Salesforce_1 GROUP BY Page_Origin__c ORDER BY COUNT(*) DESC

-- P5 : statuts reels des leads
SELECT Status, COUNT(*) AS N FROM Lead_Salesforce_1 GROUP BY Status ORDER BY COUNT(*) DESC

-- P6 : la colonne Domain existe-t-elle dans _Sent ? (necessaire pour les insights domaines)
SELECT TOP 5 Domain, JobID, EventDate FROM _Sent WHERE EventDate >= DATEADD(day, -7, GETDATE())

-- P7 : noms d emails reels (_Job.EmailName) pour verifier le parsing FR/NL, tirets, PET, HOM
SELECT TOP 40 EmailName, COUNT(*) AS N FROM _Job WHERE EmailName LIKE 'MKT[_]%' OR EmailName LIKE 'O__[_]%' GROUP BY EmailName ORDER BY COUNT(*) DESC
