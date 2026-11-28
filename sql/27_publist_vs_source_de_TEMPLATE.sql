SELECT
    x.Issue AS Issue,
    COUNT(*) AS Subscribers
FROM (
    SELECT 'In the source DE but not active on the list' AS Issue
    FROM SOURCE_DE_NAME d
    LEFT JOIN (SELECT ls.SubscriberKey AS SubscriberKey
               FROM _ListSubscribers ls
               JOIN _List l ON l.ListID = ls.ListID
               WHERE l.ListName = 'LIST_NAME' AND ls.Status = 'Active') a ON a.SubscriberKey = d.SubscriberKey
    WHERE a.SubscriberKey IS NULL
    UNION ALL
    SELECT 'Active on the list but not in the source DE' AS Issue
    FROM (SELECT ls.SubscriberKey AS SubscriberKey
          FROM _ListSubscribers ls
          JOIN _List l ON l.ListID = ls.ListID
          WHERE l.ListName = 'LIST_NAME' AND ls.Status = 'Active') a
    LEFT JOIN SOURCE_DE_NAME d ON d.SubscriberKey = a.SubscriberKey
    WHERE d.SubscriberKey IS NULL
) x
GROUP BY x.Issue
