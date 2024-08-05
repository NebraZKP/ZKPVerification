-- WARNING: this query may be part of multiple repos
-- part of a query repo
-- query name: ZKP Projects Comparison (L30D)
-- query link: https://dune.com/queries/3919432


with base as (
    -- infra/rollup
    select 'infra' as type, 'Ethereum' as chain, 'zkSync Era' as protocol, * from dune.nebra.result_zksync_era_verification_base -- https://dune.com/queries/3890722
    UNION ALL
    select 'infra' as type, 'Ethereum' as chain, 'Scroll' as protocol, * from dune.nebra.result_scroll_verification_base -- https://dune.com/queries/3916549
    UNION ALL
    select 'infra' as type, 'Ethereum' as chain, 'Linea' as protocol, * from dune.nebra.result_linea_verification_base -- https://dune.com/queries/3916566
    UNION ALL
    select 'infra' as type, 'Ethereum' as chain, 'Loopring' as protocol, * from dune.nebra.result_loopring_verfication_base -- https://dune.com/queries/3902706
    UNION ALL
    select 'infra' as type, 'Ethereum' as chain, 'Aztec' as protocol, * from dune.nebra.result_aztec_verification_base -- https://dune.com/queries/3916310
    UNION ALL
    select 'infra' as type, 'Ethereum' as chain, 'Polygon zkEVM' as protocol, * from dune.nebra.result_polygon_zk_evm_verification_base -- https://dune.com/queries/3916389
    UNION ALL
    select 'infra' as type, 'Ethereum' as chain, 'Starknet' as protocol, * from dune.nebra.result_starknet_verification_base -- https://dune.com/queries/3948217
    
    
    -- app
    UNION ALL
    select 'app' as type, 'Ethereum' as chain, 'dYdX (StarkEx)' as protocol, * from dune.nebra.result_dydx_stark_ex_verification_base -- https://dune.com/queries/3902468
    UNION ALL
    select 'app' as type, 'Ethereum' as chain, 'Tornado Cash' as protocol, * from dune.nebra.result_tornado_cash_verification_base -- https://dune.com/queries/3902791
    UNION ALL
    select 'app' as type, 'Ethereum' as chain, 'Nocturne' as protocol, * from dune.nebra.result_nocturne_verification_base -- https://dune.com/queries/3916443
    UNION ALL
    select 'app' as type, 'Ethereum' as chain, 'Railgun' as protocol, * from dune.nebra.result_railgun_verification_base -- https://dune.com/queries/3902794
    
    -- exclude because it's on OP/L2
    -- select 'infra' as type, 'Ethereum' as chain, 'Worldcoin' as protocol, * from dune.nebra.result_worldcoin_op_verification_base -- https://dune.com/queries/3902422
)

, zkp_agg as (
    select sum(verifying_cost_eth) as verifying_cost_eth 
        -- , sum(verifying_cost_usd) as verifying_cost_usd
    from base
    where
        ('{{time_range}}' = 'last 3 days' and block_date >= date_trunc('day', NOW() - interval '3' day))
        or ('{{time_range}}' = 'last 7 days' and block_date >= date_trunc('day', NOW() - interval '7' day))
        or ('{{time_range}}' = 'last 30 days' and block_date >= date_trunc('day', NOW() - interval '30' day))
        or ('{{time_range}}' = 'all time range possible')
)

, eth_overall as ( -- https://dune.com/queries/3964097/6670658
    select sum(fees) as overall_gas_eth
    -- , sum(fees * pu.price) as overall_gas_usd
    from (
        SELECT t.block_time
            , case when "type" = 'Legacy' then '0: Legacy'
                when "type" = 'AccessList' then '1: AccessList'
                when "type" = 'DynamicFee' then '2: EIP-1559'
                when "type" = '3' then '3: Blob'
            end as "type"
            , CASE WHEN t."type"='Legacy' THEN CAST(t.gas_used/1e18 AS double) * t.gas_price -- for legacy transactions
                WHEN t."type"='DynamicFee' THEN CAST(t.gas_used/1e18 AS double) * (b.base_fee_per_gas + t.priority_fee_per_gas) -- for EIP-1559 transactions
                WHEN t."type"='3' THEN CAST(t.gas_used/1e18 AS double) * (b.base_fee_per_gas + t.priority_fee_per_gas) + cardinality(blob_versioned_hashes)*power(2, 17) * gp.blob_base_fee/1e18 -- for Blob transactions, need to add blob data fee | 2^17 is because each blob stores 128KB of data which is 131072 bytes which is 2^17 bytes
            END AS fees
        FROM ethereum.transactions t
        INNER JOIN ethereum.blocks b ON t.block_number = b.number
        INNER JOIN dune.resident_wizards.dataset_blob_base_fees_lookup gp USING (excess_blob_gas) --https://dune.com/queries/3521876
        INNER JOIN beacon.blobs blob on blob.parent_root = b.parent_beacon_block_root and blob.block_date = b.date
        WHERE t."type" != 'AccessList'
        
        union all 
        
        SELECT t.block_time
            , case when "type" = 'Legacy' then '0: Legacy'
                when "type" = 'AccessList' then '1: AccessList'
                when "type" = 'DynamicFee' then '2: EIP-1559'
                when "type" = '3' then '3: Blob'
            end as "type"
            , CASE WHEN t."type"='AccessList' THEN CAST(t.gas_used/1e18 AS double) * t.gas_price + cardinality(t.access_list) * 2400 / 1e9 + cardinality(elem.storageKeys) * 1900 / 1e9 -- https://eips.ethereum.org/EIPS/eip-2930
            END AS fees
        FROM ethereum.transactions t, UNNEST(t.access_list) AS elem
        WHERE t."type" = 'AccessList'
    )
    -- LEFT JOIN prices.usd pu ON pu.blockchain IS NULL
    --     AND pu.symbol='ETH'
    --     AND pu.minute=date_trunc('minute', block_time)
    where
        ('{{time_range}}' = 'last 3 days' and block_time >= date_trunc('day', NOW() - interval '3' day))
        or ('{{time_range}}' = 'last 7 days' and block_time >= date_trunc('day', NOW() - interval '7' day))
        or ('{{time_range}}' = 'last 30 days' and block_time >= date_trunc('day', NOW() - interval '30' day))
        or ('{{time_range}}' = 'all time range possible')
)

select verifying_cost_eth / overall_gas_eth * 100 as percent_zk_gas_eth -- to make pct for counter
    -- , verifying_cost_usd / overall_gas_usd as percent_zk_gas_usd
from zkp_agg, eth_overall