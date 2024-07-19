-- part of a query repo
-- query name: polygonZkEVM verification base
-- query link: https://dune.com/queries/3916389


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
    -- if we want to hardcode can do https://github.com/0xPolygonHermez/zkevm-contracts/blob/73758334f8568b74e9493fcc530b442bd73325dc/gas_report.md?plain=1#L68C41-L68C71
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price) as verifying_cost_ETH -- gas in gwei, so divide by 1e9
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price * avg_eth_price) as verifying_cost_usd 
from ethereum.transactions tx 
left join ethereum.traces tr on tr.block_number = tx.block_number and tr.tx_hash = tx.hash
left join eth_usd_price ep on tr.block_date = ep.day
left join eth_gas_price gp on tr.block_date = gp.day
WHERE tx.to = 0x5132A183E9F3CB7C848b0AAC5Ae0c4f0491B7aB2
    and (
        bytearray_substring(tx.data, 1, 4) = 0x1489ed10 -- verifyBatchesTrustedAggregator -- https://etherscan.io/tx/0xf151bd2f9cfa516038d313267086bf5fd5cb2f35049aa1cba17ea9661a8f832f
        or bytearray_substring(tx.data, 1, 4) = 0x2b0006fa -- verifyBatchesTrustedAggregator -- https://etherscan.io/tx/0x057b8d070516fde8195480fca1ebdb28d557dfad2d39b8ce78d64d86106a97b4
        or bytearray_substring(tx.data, 1, 4) = 0xa50a164b -- verifyBatchesTrustedAggregator -- https://etherscan.io/tx/0xd8e6c7190958d90760dbbf1735f0127b09a9b9b8c16162102c64a0d04d6f5f0d
    )
    and tr.call_type = 'staticcall' 
    -- and tr.to in (0x0775e11309d75aa6b0967917fb0213c5673edf81, 0x5f411584e02964a028e3123c833c352cd2f5cbd5, 0x21f65deadb3b85082BA99766f323bEA90eb5a3D6, 0x4F9A0e7FD2Bf6067db6994CF12E4495Df938E6e9) -- FflonkVerifier
    -- and tx.block_number = 20268735 and tx.hash = 0x31a15dc35c3f30128e2ae4213af4a2415dc46372de8404f43a1ee851f75c51cf -- https://etherscan.io/tx/0x59fd8268be53ba38b267696270e3a09d2768036295552f19ca5edc607a3faa41/advanced#internal --> 59028
group by 1