WITH paid_sessions AS (
    SELECT
        s.visitor_id,
        s.visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign
    FROM sessions AS s
    WHERE s.medium IN (
        'cpc',
        'cpm',
        'cpa',
        'youtube',
        'cpp',
        'tg',
        'social'
    )
),

last_paid_session AS (
    SELECT
        visitor_id,
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        ROW_NUMBER() OVER (
            PARTITION BY visitor_id
            ORDER BY visit_date DESC
        ) AS rn
    FROM paid_sessions
),

visitors AS (
    SELECT
        visit_date::date AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        COUNT(DISTINCT visitor_id) AS visitors_count
    FROM last_paid_session
    WHERE rn = 1
    GROUP BY
        visit_date::date,
        utm_source,
        utm_medium,
        utm_campaign
),

last_paid_click AS (
    SELECT
        s.visitor_id,
        s.visit_date::date AS visit_date,
        s.utm_source,
        s.utm_medium,
        s.utm_campaign,
        l.lead_id,
        l.amount,
        l.status_id,
        ROW_NUMBER() OVER (
            PARTITION BY l.lead_id
            ORDER BY s.visit_date DESC
        ) AS rn
    FROM paid_sessions AS s
    INNER JOIN leads AS l
        ON s.visitor_id = l.visitor_id
       AND s.visit_date <= l.created_at
),

leads_data AS (
    SELECT
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        COUNT(DISTINCT lead_id) AS leads_count,
        COUNT(DISTINCT lead_id) FILTER (
            WHERE status_id = 142
        ) AS purchases_count,
        SUM(amount) FILTER (
            WHERE status_id = 142
        ) AS revenue
    FROM last_paid_click
    WHERE rn = 1
    GROUP BY
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign
),

ads AS (
    SELECT
        campaign_date::date AS visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent) AS total_cost
    FROM (
        SELECT
            campaign_date,
            utm_source,
            utm_medium,
            utm_campaign,
            daily_spent
        FROM vk_ads

        UNION ALL

        SELECT
            campaign_date,
            utm_source,
            utm_medium,
            utm_campaign,
            daily_spent
        FROM ya_ads
    ) AS all_ads
    GROUP BY
        campaign_date::date,
        utm_source,
        utm_medium,
        utm_campaign
)

SELECT
    TO_CHAR(v.visit_date, 'YYYY-MM-DD') AS visit_date,
    v.visitors_count,
    v.utm_source,
    v.utm_medium,
    v.utm_campaign,
    a.total_cost,
    COALESCE(l.leads_count, 0) AS leads_count,
    COALESCE(l.purchases_count, 0) AS purchases_count,
    l.revenue
FROM visitors AS v
LEFT JOIN ads AS a
    USING (visit_date, utm_source, utm_medium, utm_campaign)
LEFT JOIN leads_data AS l
    USING (visit_date, utm_source, utm_medium, utm_campaign)
ORDER BY
    v.visit_date,
    v.visitors_count DESC,
    v.utm_source,
    v.utm_medium,
    v.utm_campaign,
    l.revenue DESC NULLS LAST;