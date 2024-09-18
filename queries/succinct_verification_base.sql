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

select
  block_date,
  count(distinct tx_hash) as verifying_calls,
  sum(cast(gas_used as double) / 1e9 * median_gas_price) as verifying_cost_ETH,
  sum(
    cast(gas_used as double) / 1e9 * median_gas_price * avg_eth_price
  ) as verifying_cost_usd
from
  ethereum.traces
  left join eth_usd_price ep on block_date = ep.day
  left join eth_gas_price gp on block_date = gp.day
where
  to = 0x3B6041173B80E77f038f3F2C0f9744f04837185e -- SP1VerifierGateway
  and bytearray_substring (input, 1, 4) = 0x41493c60 -- verifyProof
group by 1