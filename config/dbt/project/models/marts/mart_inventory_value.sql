{{
    config(
        materialized='table',
        distributed_by='HASH(product_id)',
        buckets=3,
        properties={
            'replication_num': '1'
        }
    )
}}

SELECT
    product_id,
    product_name,
    category,
    price,
    stock_quantity,
    price * stock_quantity AS inventory_value,
    CASE
        WHEN stock_quantity < 20 THEN 'Low'
        WHEN stock_quantity < 100 THEN 'Medium'
        ELSE 'High'
    END AS stock_level,
    last_updated,
    CURRENT_TIMESTAMP() AS _calculated_at
FROM {{ ref('stg_products') }}
