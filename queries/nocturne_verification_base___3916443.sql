-- part of a query repo
-- query name: Nocturne verification base
-- query link: https://dune.com/queries/3916443


/*
https://nocturne-xyz.gitbook.io/nocturne/developers/contract-addresses --> find Teller proxy 0xA561492dFC1A90418Cc8b9577204d56C17CB32Ff
inside Teller implementation contract --> function processBundle -> Processes a bundle of operations. Verifies all proofs 
*/

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
    , count(distinct r.call_tx_hash) as verifying_calls
    , sum(case when tx.type = 'DynamicFee' then cast(tr.gas_used as double) * median_dynamic_gas_price -- dynamic 
            else cast(tr.gas_used as double) * median_legacy_gas_price -- legacy
        end) as verifying_cost_ETH
        , sum(case when tx.type = 'DynamicFee' then cast(tr.gas_used as double) * median_dynamic_gas_price * avg_eth_price -- dynamic 
            else cast(tr.gas_used as double) * median_legacy_gas_price * avg_eth_price -- legacy
        end) as verifying_cost_usd
from nocturne_ethereum.Teller_call_processBundle r 
left join ethereum.traces tr on tr.block_number = r.call_block_number and tr.tx_hash = r.call_tx_hash
inner join ethereum.transactions tx on tr.block_number = tx.block_number and tr.tx_hash = tx.hash
left join eth_usd_price ep on tr.block_date = ep.day
left join eth_gas_price gp on tr.block_date = gp.day
where 1=1
    and tr.call_type = 'staticcall' and tr.to = 0xbe2810d1a29f9fb00ac97b0024bc7794f9c59046 -- JoinSplitVerifier
    -- and r.call_block_number = 19841992 and r.call_tx_hash = 0xba5b2e015c8b885a62b5688a0e139bd6c1a81e4e8e3a67bff402e7a8cf4e898b
    -- and tr.block_date >= now() - interval '14' day
group by 1


