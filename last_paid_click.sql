-- ============================================================
-- Modelo de atribución: Last Paid Click
-- Identifica el último clic pagado antes de la conversión a lead
-- ============================================================

WITH paid_sessions AS (
    -- Solo sesiones que llegaron por un canal pagado
    SELECT
        visitor_id,
        visit_date,
        source   AS utm_source,
        medium   AS utm_medium,
        campaign AS utm_campaign
    FROM sessions
    WHERE medium IN ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

lead_candidates AS (
    -- Para cada lead, todas las visitas pagadas del mismo visitante
    -- ocurridas antes (o al momento) de la creación del lead
    SELECT
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        ps.visitor_id,
        ps.visit_date,
        ps.utm_source,
        ps.utm_medium,
        ps.utm_campaign,
        ROW_NUMBER() OVER (
            PARTITION BY l.lead_id
            ORDER BY ps.visit_date DESC
        ) AS rn
    FROM leads l
    JOIN paid_sessions ps
        ON ps.visitor_id = l.visitor_id
        AND ps.visit_date <= l.created_at
),

attributed AS (
    -- Nos quedamos solo con el último clic pagado antes de cada lead
    -- (una fila por lead, con la sesión que se lleva el crédito)
    SELECT
        visitor_id,
        visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        lead_id,
        created_at,
        amount,
        closing_reason,
        status_id
    FROM lead_candidates
    WHERE rn = 1
)

-- Todas las visitas pagadas, con los datos del lead si esa visita
-- fue el último clic antes de una conversión (NULL si no lo fue)
SELECT
    ps.visitor_id,
    ps.visit_date,
    ps.utm_source,
    ps.utm_medium,
    ps.utm_campaign,
    a.lead_id,
    a.created_at,
    a.amount,
    a.closing_reason,
    a.status_id
FROM paid_sessions ps
LEFT JOIN attributed a
    ON a.visitor_id    = ps.visitor_id
    AND a.visit_date   = ps.visit_date
    AND a.utm_source   = ps.utm_source
    AND a.utm_medium   = ps.utm_medium
    AND a.utm_campaign = ps.utm_campaign
ORDER BY
    a.amount DESC NULLS LAST,
    ps.visit_date ASC,
    ps.utm_source ASC,
    ps.utm_medium ASC,
    ps.utm_campaign ASC;