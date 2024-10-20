-- part of a query repo
-- query name: Succinct verification base
-- query link: https://dune.com/queries/tbd

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

select tr.block_date 
    , count(distinct tx_hash) as verifying_calls
    , sum(case when tx.type = 'DynamicFee' then cast(tr.gas_used as double) * median_dynamic_gas_price -- dynamic 
        else cast(tr.gas_used as double) * median_legacy_gas_price -- legacy
    end) as verifying_cost_ETH
    , sum(case when tx.type = 'DynamicFee' then cast(tr.gas_used as double) * median_dynamic_gas_price * avg_eth_price -- dynamic 
        else cast(tr.gas_used as double) * median_legacy_gas_price * avg_eth_price -- legacy
    end) as verifying_cost_usd
from ethereum.traces tr
left join ethereum.transactions tx on tr.block_number = tx.block_number and tr.tx_hash = tx.hash
left join eth_usd_price ep on tr.block_date = ep.day
left join eth_gas_price gp on tr.block_date = gp.day
where
    tr.to = 0x3B6041173B80E77f038f3F2C0f9744f04837185e -- SP1VerifierGateway
    and tr.call_type = 'staticcall'
    and bytearray_substring (input, 1, 4) = 0x41493c60 -- verifyProof
group by 1