{{
    config(
        materialized='table',
        distributed_by='HASH(category)',
        buckets=3,
        properties={
            'replication_num': '1'
        }
    )
}}

SELECT
    category,
    COUNT(*) AS product_count,
    AVG(price) AS avg_price,
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    SUM(stock_quantity) AS total_stock,
    MAX(last_updated) AS last_product_update,
    CURRENT_TIMESTAMP() AS _refreshed_at
FROM {{ ref('stg_products') }}
GROUP BY category
