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
    last_updated,
    CURRENT_TIMESTAMP() AS _loaded_at
FROM {{ source('mysql_source', 'products') }}
