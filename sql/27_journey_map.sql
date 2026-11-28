SELECT DISTINCT
    k.JourneyName AS JourneyName
FROM DASH_Journey_KPI_Monthly k
WHERE k.JourneyName IS NOT NULL
  AND LEFT(k.JourneyName, 3) <> 'MKT'
