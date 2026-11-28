SELECT
    l.ListName AS ListName,
    l.ListType AS ListType,
    COUNT(ls.SubscriberKey) AS Members,
    SUM(CASE WHEN ls.Status = 'Active' THEN 1 ELSE 0 END) AS ActiveMembers
FROM _List l
LEFT JOIN _ListSubscribers ls ON ls.ListID = l.ListID
GROUP BY l.ListName, l.ListType
