SELECT a.Month AS Month, a.Reason AS Reason, COUNT(*) AS Leads
FROM DASH_Audit_Leads a
GROUP BY a.Month, a.Reason
