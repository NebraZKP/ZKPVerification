-- part of a query repo
-- query name: Scroll verification base
-- query link: https://dune.com/queries/3916549


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

select 
    -- tr.*
    tr.block_date 
    , count(distinct tx_hash) as verifying_calls
    , sum(case when tx.type = 'Legacy' then cast(tr.gas_used as double)  * median_legacy_gas_price -- legacy
        when tx.type = 'DynamicFee' then cast(tr.gas_used as double)  * median_dynamic_gas_price -- dynamic 
        -- should only be these 2 txn types, blob and AccessList don't apply 
    end) as verifying_cost_ETH
    , sum(case when tx.type = 'Legacy' then cast(tr.gas_used as double)  * median_legacy_gas_price * avg_eth_price -- legacy
        when tx.type = 'DynamicFee' then cast(tr.gas_used as double)  * median_dynamic_gas_price * avg_eth_price -- dynamic 
    end) as verifying_cost_usd
from ethereum.transactions tx
left join ethereum.traces tr on tr.block_number = tx.block_number and tr.tx_hash = tx.hash
left join eth_usd_price ep on tr.block_date = ep.day
left join eth_gas_price gp on tr.block_date = gp.day
where 1=1
    -- and varbinary_substring(tx.data, 1, 4) = 0x00b0f4d7 -- finalizeBatchWithProof4844, not needed
    -- tx.to = 0xa13BAF47339d63B743e7Da8741db5456DAc1E556 -- Scroll L1 rollup proxy, but not needed
    and tx."from" = 0x356483dC32B004f32Ea0Ce58F7F88879886e9074 -- bathch finalizer, per Scroll team this is the correct address
    and tr.call_type = 'staticcall' -- assuming that verifier contract should be called as readonly staticcalls (next best to identifying all verifier contracts which is pretty impossible manually)
    
    -- and tx.block_date >= now() - interval '7' day
    -- and tx.block_number = 20301391 and tx.hash = 0x59fd8268be53ba38b267696270e3a09d2768036295552f19ca5edc607a3faa41 -- https://etherscan.io/tx/0x59fd8268be53ba38b267696270e3a09d2768036295552f19ca5edc607a3faa41/advanced#internal --> 200,549
group by 1