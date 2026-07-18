WITH visitors AS (
    SELECT
        s.visit_date::date AS visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        COUNT(DISTINCT s.visitor_id) AS visitors_count
    FROM sessions s
    WHERE s.medium IN (
        'cpc',
        'cpm',
        'cpa',
        'youtube',
        'cpp',
        'tg',
        'social'
    )
    GROUP BY
        s.visit_date::date,
        s.source,
        s.medium,
        s.campaign
),

last_paid_click AS (
    SELECT
        s.visitor_id,
        s.visit_date::date AS visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        l.lead_id,
        l.amount,
        l.closing_reason,
        l.status_id,
        ROW_NUMBER() OVER (
            PARTITION BY l.lead_id
            ORDER BY s.visit_date DESC
        ) AS rn
    FROM sessions s
    LEFT JOIN leads l
        ON s.visitor_id = l.visitor_id
       AND s.visit_date <= l.created_at
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

leads_data AS (
    SELECT
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        COUNT(lead_id) AS leads_count,
        COUNT(
            CASE
                WHEN closing_reason = 'Completado con éxito'
                  OR status_id = 142
                THEN 1
            END
        ) AS purchases_count,
        SUM(
            CASE
                WHEN closing_reason = 'Completado con éxito'
                  OR status_id = 142
                THEN amount
            END
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
    FROM vk_ads
    GROUP BY
        campaign_date::date,
        utm_source,
        utm_medium,
        utm_campaign

    UNION ALL

    SELECT
        campaign_date::date,
        utm_source,
        utm_medium,
        utm_campaign,
        SUM(daily_spent)
    FROM ya_ads
    GROUP BY
        campaign_date::date,
        utm_source,
        utm_medium,
        utm_campaign
)

SELECT
    v.visit_date,
    v.visitors_count,
    v.utm_source,
    v.utm_medium,
    v.utm_campaign,
    a.total_cost,
    COALESCE(l.leads_count, 0) AS leads_count,
    COALESCE(l.purchases_count, 0) AS purchases_count,
    l.revenue
FROM visitors v
LEFT JOIN ads a
    ON v.visit_date = a.visit_date
   AND v.utm_source = a.utm_source
   AND v.utm_medium = a.utm_medium
   AND v.utm_campaign = a.utm_campaign
LEFT JOIN leads_data l
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
