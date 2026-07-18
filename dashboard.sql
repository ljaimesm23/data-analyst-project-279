-- Cálculo de los gastos publicitarios
--Qué hace esta consulta:

--✅ Une visitas (sessions) con campañas publicitarias (vk_ads y ya_ads)
--✅ Calcula gasto total diario por UTM
--✅ Cuenta visitantes por campaña
--✅ Cuenta leads generados
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


--Cálculo de métricas En esta etapa vas a crear un dashboard para el equipo de marketing, 
--que les ayude a analizar la calidad del tráfico y a responder preguntas clave como: 
--¿Cuántas personas visitan nuestro sitio? ¿Qué canales las están trayendo? (queremos verlo por día, semana y mes) 
--¿Cuántos leads estamos generando? ¿Cuál es la conversión de clic → lead? ¿Y de lead → venta? 
--¿Cuánto estamos gastando en cada canal a lo largo del tiempo? 
--¿Se están rentabilizando esos canales?

--1) Crear tabla resumen agregada por utm_source
WITH marketing_data AS (

    SELECT
        s.visit_date::date AS visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,
        COUNT(DISTINCT s.visitor_id) AS visitors_count,

        COUNT(DISTINCT l.lead_id) AS leads_count,

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
),

costs AS (

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

summary AS (

SELECT
    m.visit_date,
    m.utm_source,
    m.utm_medium,
    m.utm_campaign,

    m.visitors_count,
    c.total_cost,
    m.leads_count,
    m.purchases_count,
    m.revenue

FROM marketing_data m

LEFT JOIN costs c
ON m.visit_date = c.visit_date
AND m.utm_source = c.utm_source
AND m.utm_medium = c.utm_medium
AND m.utm_campaign = c.utm_campaign

)

SELECT
    utm_source,

    SUM(visitors_count) AS visitors_count,
    SUM(total_cost) AS total_cost,
    SUM(leads_count) AS leads_count,
    SUM(purchases_count) AS purchases_count,
    SUM(revenue) AS revenue,

    -- costo por usuario
    SUM(total_cost) /
    NULLIF(SUM(visitors_count),0) AS cpu,

    -- costo por lead
    SUM(total_cost) /
    NULLIF(SUM(leads_count),0) AS cpl,

    -- costo por venta
    SUM(total_cost) /
    NULLIF(SUM(purchases_count),0) AS cppu,

    -- retorno inversión
    (SUM(revenue)-SUM(total_cost))
    /
    NULLIF(SUM(total_cost),0)
    *100 AS roi

FROM summary

GROUP BY
    utm_source

ORDER BY
    roi DESC NULLS LAST;
--2) Análisis detallado por campaña
--Para el análisis detallado por campaña, métricas adicionales y filtros del dashboard, puedes crear una vista completa que incluya:

--Fecha
--UTM Source
--UTM Medium
--UTM Campaign
--Visitas
--Costos
--Leads
--Ventas
--Revenue
--CPU
--CPL
--CPPU
--ROI
--Conversión visita → lead
--Conversión lead → venta
WITH marketing_data AS (

    SELECT
        s.visit_date::date AS visit_date,
        s.source AS utm_source,
        s.medium AS utm_medium,
        s.campaign AS utm_campaign,

        COUNT(DISTINCT s.visitor_id) AS visitors_count,

        COUNT(DISTINCT l.lead_id) AS leads_count,

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
),


advertising_costs AS (

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


campaign_summary AS (

    SELECT

        m.visit_date,

        m.utm_source,

        m.utm_medium,

        m.utm_campaign,


        m.visitors_count,

        COALESCE(c.total_cost,0) AS total_cost,

        m.leads_count,

        m.purchases_count,

        COALESCE(m.revenue,0) AS revenue


    FROM marketing_data m


    LEFT JOIN advertising_costs c

        ON m.visit_date = c.visit_date

        AND m.utm_source = c.utm_source

        AND m.utm_medium = c.utm_medium

        AND m.utm_campaign = c.utm_campaign

)


SELECT


    visit_date,


    utm_source,


    utm_medium,


    utm_campaign,


    visitors_count,


    total_cost,


    leads_count,


    purchases_count,


    revenue,


    -- Costo por usuario
    ROUND(
        total_cost /
        NULLIF(visitors_count,0),
        2
    ) AS cpu,


    -- Costo por lead
    ROUND(
        total_cost /
        NULLIF(leads_count,0),
        2
    ) AS cpl,


    -- Costo por venta
    ROUND(
        total_cost /
        NULLIF(purchases_count,0),
        2
    ) AS cppu,


    -- ROI %
    ROUND(
        (
            (revenue - total_cost)
            /
            NULLIF(total_cost,0)
        ) * 100,
        2
    ) AS roi,


    -- Conversión visita → lead
    ROUND(
        (
            leads_count /
            NULLIF(visitors_count,0)
        ) * 100,
        2
    ) AS visit_to_lead_conversion,


    -- Conversión lead → venta
    ROUND(
        (
            purchases_count /
            NULLIF(leads_count,0)
        ) * 100,
        2
    ) AS lead_to_sale_conversion,


    -- Agrupación semanal para dashboard
    DATE_TRUNC(
        'week',
        visit_date
    ) AS week,


    -- Agrupación mensual para dashboard
    DATE_TRUNC(
        'month',
        visit_date
    ) AS month


FROM campaign_summary


ORDER BY

    visit_date ASC,

    visitors_count DESC,

    utm_source ASC,

    utm_medium ASC,

    utm_campaign ASC,

    revenue DESC NULLS LAST;

--¿Cuántas personas visitan nuestro sitio?
SELECT
    COUNT(DISTINCT visitor_id) AS visitors
FROM sessions;


SELECT
    visit_date::date AS date,
    COUNT(DISTINCT visitor_id) AS visitors_count
FROM sessions
GROUP BY
    visit_date::date
ORDER BY
    date;

-- por canal
SELECT
    source AS utm_source,
    COUNT(DISTINCT visitor_id) AS visitors_count
FROM sessions
GROUP BY
    source
ORDER BY
    visitors_count DESC;

--¿Cuántos leads estamos generando?
SELECT
    COUNT(lead_id) AS total_leads
FROM leads;

--¿Cuál es la conversión de clic → lead?
SELECT

COUNT(DISTINCT l.lead_id) /
COUNT(DISTINCT s.visitor_id)::numeric
*100 AS click_to_lead_conversion

FROM sessions s

LEFT JOIN leads l
ON s.visitor_id = l.visitor_id;

--¿Cuál es la conversión de lead → venta?
SELECT

COUNT(
CASE
WHEN closing_reason='Completado con éxito'
OR status_id=142
THEN lead_id
END
)
/
COUNT(lead_id)::numeric
*100 AS lead_to_sale_conversion

FROM leads;

--¿Cuánto estamos gastando en cada canal a lo largo del tiempo?
WITH advertising_costs AS (

    SELECT
        campaign_date::date AS date,
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent AS cost

    FROM vk_ads


    UNION ALL


    SELECT
        campaign_date::date AS date,
        utm_source,
        utm_medium,
        utm_campaign,
        daily_spent AS cost

    FROM ya_ads
)


SELECT

    date,

    utm_source,

    SUM(cost) AS total_cost


FROM advertising_costs


GROUP BY

    date,
    utm_source


ORDER BY

    date ASC,
    total_cost DESC;
    
--¿Se están rentabilizando esos canales?
WITH advertising_costs AS (

    SELECT
        campaign_date::date AS date,
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
        campaign_date::date AS date,
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


campaign_revenue AS (

    SELECT

        s.visit_date::date AS date,

        s.source AS utm_source,

        s.medium AS utm_medium,

        s.campaign AS utm_campaign,


        COUNT(DISTINCT s.visitor_id) AS visitors_count,


        COUNT(DISTINCT l.lead_id) AS leads_count,


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
                ELSE 0
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

    c.date,

    c.utm_source,

    c.utm_medium,

    c.utm_campaign,


    c.total_cost,


    COALESCE(r.visitors_count,0) AS visitors_count,

    COALESCE(r.leads_count,0) AS leads_count,

    COALESCE(r.purchases_count,0) AS purchases_count,

    COALESCE(r.revenue,0) AS revenue,


    -- Costo por visitante
    ROUND(
        c.total_cost /
        NULLIF(r.visitors_count,0),
        2
    ) AS cpu,


    -- Costo por lead
    ROUND(
        c.total_cost /
        NULLIF(r.leads_count,0),
        2
    ) AS cpl,


    -- Costo por venta
    ROUND(
        c.total_cost /
        NULLIF(r.purchases_count,0),
        2
    ) AS cppu,


    -- ROI %
    ROUND(
        (
            (COALESCE(r.revenue,0) - c.total_cost)
            /
            NULLIF(c.total_cost,0)
        ) * 100,
        2
    ) AS roi


FROM advertising_costs c


LEFT JOIN campaign_revenue r

    ON c.date = r.date

    AND c.utm_source = r.utm_source

    AND c.utm_medium = r.utm_medium

    AND c.utm_campaign = r.utm_campaign


ORDER BY

    roi DESC NULLS LAST,

    c.date ASC,

    c.utm_source ASC;


--¿Qué canales son rentables? ¿Cuáles exactamente?
WITH costs AS (

    SELECT
        utm_source,
        SUM(daily_spent) AS total_cost
    FROM vk_ads
    GROUP BY utm_source

    UNION ALL

    SELECT
        utm_source,
        SUM(daily_spent) AS total_cost
    FROM ya_ads
    GROUP BY utm_source
),


revenue AS (

    SELECT

        s.source AS utm_source,

        SUM(
            CASE
                WHEN l.closing_reason = 'Completado con éxito'
                     OR l.status_id = 142
                THEN l.amount
                ELSE 0
            END
        ) AS revenue


    FROM sessions s

    LEFT JOIN leads l
        ON s.visitor_id = l.visitor_id


    GROUP BY
        s.source
)


SELECT

    c.utm_source,

    SUM(c.total_cost) AS total_cost,

    COALESCE(r.revenue,0) AS revenue,


    ROUND(
        (
            (COALESCE(r.revenue,0)-SUM(c.total_cost))
            /
            NULLIF(SUM(c.total_cost),0)
        )*100,
        2
    ) AS roi


FROM costs c


LEFT JOIN revenue r

ON c.utm_source = r.utm_source


GROUP BY

    c.utm_source,

    r.revenue


ORDER BY

    roi DESC;
    
--¿Qué canales conviene pausar, en cuáles mejorar la ejecución y cuáles mantener tal como están porque funcionan muy bien?
WITH costs AS (

    SELECT
        utm_source,
        SUM(daily_spent) AS total_cost
    FROM vk_ads
    GROUP BY utm_source

    UNION ALL

    SELECT
        utm_source,
        SUM(daily_spent) AS total_cost
    FROM ya_ads
    GROUP BY utm_source
),


revenue AS (

    SELECT

        s.source AS utm_source,

        SUM(
            CASE
                WHEN l.closing_reason = 'Completado con éxito'
                     OR l.status_id = 142
                THEN l.amount
                ELSE 0
            END
        ) AS revenue

    FROM sessions s

    LEFT JOIN leads l
        ON s.visitor_id = l.visitor_id

    GROUP BY
        s.source
),


channel_roi AS (

    SELECT

        c.utm_source,

        SUM(c.total_cost) AS total_cost,

        COALESCE(r.revenue,0) AS revenue,


        (
            (COALESCE(r.revenue,0)-SUM(c.total_cost))
            /
            NULLIF(SUM(c.total_cost),0)
        ) * 100 AS roi


    FROM costs c


    LEFT JOIN revenue r

        ON c.utm_source = r.utm_source


    GROUP BY

        c.utm_source,

        r.revenue
)


SELECT

    utm_source,

    total_cost,

    revenue,

    ROUND(roi,2) AS roi,


    CASE

        WHEN roi >= 100 THEN 'Mantener / aumentar inversión'

        WHEN roi >= 0 AND roi < 100 THEN 'Mejorar ejecución'

        WHEN roi < 0 THEN 'Pausar o revisar'

        ELSE 'Sin datos'

    END AS recommendation


FROM channel_roi


ORDER BY

    roi DESC NULLS LAST;
    
--Tras lanzar una campaña, ¿cuándo puede el equipo de marketing empezar a analizarla con tu dashboard? Sugerencia: calcula en cuántos días desde el clic se cierra el 90% de los leads.
WITH conversion_time AS (

SELECT

    s.visitor_id,

    l.lead_id,

    DATE(l.created_at) - DATE(s.visit_date) AS days_to_close


FROM sessions s


JOIN leads l

ON s.visitor_id = l.visitor_id


WHERE

l.closing_reason = 'Completado con éxito'

OR l.status_id = 142

)


SELECT

PERCENTILE_CONT(0.90)

WITHIN GROUP

(
ORDER BY days_to_close
)

AS days_until_90_percent_sales


FROM conversion_time;

--¿Hay correlación visible entre el inicio de campañas y el crecimiento del tráfico orgánico?
-- PARTE 1
SELECT

DATE_TRUNC('month', visit_date)::date AS month,

COUNT(DISTINCT visitor_id) AS organic_visitors


FROM sessions


WHERE source = 'organic'


GROUP BY

DATE_TRUNC('month', visit_date)


ORDER BY month;
-- PARTE 2
WITH advertising_costs AS (

    SELECT
        campaign_date::date AS date,
        daily_spent AS cost

    FROM vk_ads


    UNION ALL


    SELECT
        campaign_date::date AS date,
        daily_spent AS cost

    FROM ya_ads
)


SELECT

    DATE_TRUNC('month', date)::date AS month,

    SUM(cost) AS advertising_cost


FROM advertising_costs


GROUP BY

    DATE_TRUNC('month', date)


ORDER BY

    month;

--