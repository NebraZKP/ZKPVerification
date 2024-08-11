-- part of a query repo
-- query name: Aztec verification base
-- query link: https://dune.com/queries/3916310


with eth_gas_price as (
    SELECT DATE_TRUNC('day', tx.block_time) AS day
       , APPROX_PERCENTILE(tx.gas_price / 1e18, 0.5) AS median_legacy_gas_price
       , APPROX_PERCENTILE( (b.base_fee_per_gas + tx.priority_fee_per_gas) / 1e18, 0.5) AS median_dynamic_gas_price
    from ethereum.transactions tx
    INNER JOIN ethereum.blocks b ON tx.block_number = b.number
    group by 1
)

, eth_usd_price as (
    select date_trunc('day', minute) as day
        , avg(price) as avg_eth_price
    from prices.usd
    where blockchain is null and symbol = 'ETH'
    group by 1
)

, base as (
    select distinct tr.block_number, tr.block_date, tr.tx_hash, tr.gas_used, tr.call_type
    from aztec_v1_ethereum.RollupProcessor_evt_RollupProcessed r -- 0x737901bea3eeb88459df9ef1be8ff3ae1b42a2ba
    left join ethereum.traces tr on tr.block_number = r.evt_block_number and tr.tx_hash = r.evt_tx_hash
    where tr.call_type = 'staticcall' -- assuming that verifier contract should be called as readonly staticcalls (next best to identifying all verifier contracts which is pretty impossible manually)
        -- and r.evt_block_number = 20113626 and r.evt_tx_hash = 0xdf485f3fbd419c1bf1112afb80ddfca759fc828672238ea914c7d8add557cbdd
    
    UNION ALL
    
    select distinct tr.block_number, tr.block_date, tr.tx_hash, tr.gas_used, tr.call_type
    from aztec_v2_ethereum.RollupProcessor_evt_RollupProcessed r -- 0xff1f2b4adb9df6fc8eafecdcbf96a2b351680455
    left join ethereum.traces tr on tr.block_number = r.evt_block_number and tr.tx_hash = r.evt_tx_hash
    where tr.call_type = 'staticcall' -- assuming that verifier contract should be called as readonly staticcalls (next best to identifying all verifier contracts which is pretty impossible manually)
        -- and r.evt_block_number = 20003323 and r.evt_tx_hash = 0x12c583f32efe0c5e3f51abf18bdd7248994c28fcaa1612332af67c557fb26d20
    
    UNION ALL
    
    select distinct tr.block_number, tr.block_date, tr.tx_hash, tr.gas_used, tr.call_type
    from aztec_ethereum.RollupProcessorV2_call_processRollup r -- 0x8430be7b8fd28cc58ea70a25c9c7a624f26f5d09
    left join ethereum.traces tr on tr.block_number = r.call_block_number and tr.tx_hash = r.call_tx_hash
    where r.call_success
        and tr.call_type = 'staticcall' -- assuming that verifier contract should be called as readonly staticcalls (next best to identifying all verifier contracts which is pretty impossible manually)
        -- and r.call_block_number = 19618124 and r.call_tx_hash = 0xe0354dde3a90b9a5936ed9021cbbc5fcbf5e29c6e8206b78bd8d4e9d44ab2227
)

select b.block_date
    , count(b.tx_hash) as verifying_calls
    , sum(case when tx.type = 'DynamicFee' then cast(b.gas_used as double) * median_dynamic_gas_price -- dynamic 
        else cast(b.gas_used as double) * median_legacy_gas_price -- legacy
    end) as verifying_cost_ETH
    , sum(case when tx.type = 'DynamicFee' then cast(b.gas_used as double) * median_dynamic_gas_price * avg_eth_price -- dynamic 
        else cast(b.gas_used as double) * median_legacy_gas_price * avg_eth_price -- legacy
    end) as verifying_cost_usd
from base b 
inner join ethereum.transactions tx on b.block_number = tx.block_number and b.tx_hash = tx.hash
left join eth_usd_price ep on b.block_date = ep.day
left join eth_gas_price gp on b.block_date = gp.day
-- where b.block_date >= now() - interval '14' day
group by 1 
