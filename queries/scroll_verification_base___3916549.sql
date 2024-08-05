-- part of a query repo
-- query name: Scroll verification base
-- query link: https://dune.com/queries/3916549


with eth_gas_price as (
    SELECT DATE_TRUNC('day', block_time) AS day
        , APPROX_PERCENTILE(gas_price / 1e9, 0.5) AS median_gas_price
    from ethereum.transactions
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
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price) as verifying_cost_ETH -- gas in gwei, so divide by 1e9
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price * avg_eth_price) as verifying_cost_usd 
from ethereum.transactions tx
left join ethereum.traces tr on tr.block_number = tx.block_number and tr.tx_hash = tx.hash
left join eth_usd_price ep on tr.block_date = ep.day
left join eth_gas_price gp on tr.block_date = gp.day
where 1=1
    -- tx.to = 0xa13BAF47339d63B743e7Da8741db5456DAc1E556 -- Scroll L1 rollup proxy, but not needed
    and tx."from" = 0x356483dC32B004f32Ea0Ce58F7F88879886e9074 -- bathch finalizer, per Scroll team this is the correct address
    -- and varbinary_substring(tx.data, 1, 4) = 0x00b0f4d7 -- finalizeBatchWithProof4844, not needed
    and tr.call_type = 'staticcall' 
    -- and tx.block_number = 20301391 and tx.hash = 0x59fd8268be53ba38b267696270e3a09d2768036295552f19ca5edc607a3faa41 -- https://etherscan.io/tx/0x59fd8268be53ba38b267696270e3a09d2768036295552f19ca5edc607a3faa41/advanced#internal --> 200,549
group by 11