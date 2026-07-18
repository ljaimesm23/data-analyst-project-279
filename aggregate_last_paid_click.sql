WITH ads AS (
    SELECT
        campaign_date::date AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM vk_ads
    GROUP BY
        campaign_date::date,
        utm_source,
        utm_medium,
        utm_campaign

    UNION ALL

    SELECT
        campaign_date::date AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM ya_ads
    GROUP BY
        campaign_date::date,
        utm_source,
        utm_medium,
        utm_campaign
),

visitors AS (
    SELECT
        visit_date::date AS visit_date,
        source AS utm_source,
        medium AS utm_medium,
        campaign AS utm_campaign,
        COUNT(visitor_id) AS visitors_count
    FROM sessions
    GROUP BY
        visit_date::date,
        source,
        medium,
        campaign
),

lead_data AS (
    SELECT
        s.visit_date::date AS visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        COUNT(l.lead_id) AS leads_count,
        COUNT(
            CASE
                WHEN l.closing_reason = 'Completado con éxito'
                     OR l.status_id = 142
                THEN l.lead_id
            END
        ) AS purchases_count,
        SUM(
            CASE
                WHEN l.closing_reason = 'Completado con éxito'
                     OR l.status_id = 142
                THEN l.amount
            END
        ) AS revenue
    FROM sessions s
    LEFT JOIN leads l
        ON s.visitor_id = l.visitor_id
    GROUP BY
        s.visit_date::date,
        s.source,
        s.medium,
        s.campaign
)

SELECT
    v.visit_date,
    v.visitors_count,
    v.utm_source,
    v.utm_medium,
    v.utm_campaign,
    a.total_cost,
    l.leads_count,
    l.purchases_count,
    l.revenue
FROM visitors v

LEFT JOIN ads a
    ON v.visit_date = a.visit_date
    AND v.utm_source = a.utm_source
    AND v.utm_medium = a.utm_medium
    AND v.utm_campaign = a.utm_campaign

LEFT JOIN lead_data l
    ON v.visit_date = l.visit_date
    AND v.utm_source = l.utm_source
    AND v.utm_medium = l.utm_medium
    AND v.utm_campaign = l.utm_campaign

ORDER BY
    v.visit_date ASC,
    v.visitors_count DESC,
    v.utm_source ASC,
    v.utm_medium ASC,
    v.utm_campaign ASC,
    l.revenue DESC NULLS LAST;