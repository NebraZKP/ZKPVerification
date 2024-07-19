-- part of a query repo
-- query name: Nocturne verification base
-- query link: https://dune.com/queries/3916443


/*
https://nocturne-xyz.gitbook.io/nocturne/developers/contract-addresses --> find Teller proxy 0xA561492dFC1A90418Cc8b9577204d56C17CB32Ff
inside Teller implementation contract --> function processBundle -> Processes a bundle of operations. Verifies all proofs 
*/

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

select 
    -- tr.* 
    tr.block_date 
    , count(distinct r.call_tx_hash) as verifying_calls
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price) as verifying_cost_ETH -- gas in gwei, so divide by 1e9
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price * avg_eth_price) as verifying_cost_usd 
from nocturne_ethereum.Teller_call_processBundle r 
left join ethereum.traces tr on tr.block_number = r.call_block_number and tr.tx_hash = r.call_tx_hash
left join eth_usd_price ep on tr.block_date = ep.day
left join eth_gas_price gp on tr.block_date = gp.day
where 1=1
    and tr.call_type = 'staticcall' and tr.to = 0xbe2810d1a29f9fb00ac97b0024bc7794f9c59046 -- JoinSplitVerifier
    -- and r.call_block_number = 19841992 and r.call_tx_hash = 0xba5b2e015c8b885a62b5688a0e139bd6c1a81e4e8e3a67bff402e7a8cf4e898b
group by 1


