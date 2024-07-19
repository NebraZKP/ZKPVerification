-- part of a query repo
-- query name: Loopring verfication base
-- query link: https://dune.com/queries/3902706


with eth_gas_price as (
    SELECT DATE_TRUNC('day', block_time) AS day
       , APPROX_PERCENTILE(gas_price/ 1e9, 0.5) AS median_gas_price
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

select tr.block_date 
    , count(distinct l.call_tx_hash) as verifying_calls
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price) as verifying_cost_ETH -- gas in gwei, so divide by 1e9
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price * avg_eth_price) as verifying_cost_usd 
from loopring_ethereum.LoopringIOExchangeOwner_call_submitBlocksWithCallbacks l  
left join ethereum.traces tr on tr.block_number = l.call_block_number and tr.tx_hash = l.call_tx_hash
left join eth_usd_price ep on tr.block_date = ep.day
left join eth_gas_price gp on tr.block_date = gp.day
where l.call_success
    and tr.call_type = 'staticcall'
    -- and l.call_block_number = 20254491 and l.call_tx_hash = 0xc3bd1f86ff5252d9ec872fb7bbf6c63c3cc257fb3d68e886cdd28027e8ea36f2
group by 1 