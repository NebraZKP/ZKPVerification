-- part of a query repo
-- query name: zksync era verification base
-- query link: https://dune.com/queries/3890722



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



/* pre-Boojum: 0x3dB52cE065f728011Ac6732222270b3F2360d919 */
select tr.block_date 
    , count(pb.call_tx_hash) as verifying_calls
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price) as verifying_cost_ETH -- gas in gwei, so divide by 1e9
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price * avg_eth_price) as verifying_cost_usd 
from zksync_v2_ethereum.ValidatorTimelock_call_proveBlocks pb 
left join ethereum.traces tr on tr.block_number = pb.call_block_number and tr.tx_hash = pb.call_tx_hash
left join eth_usd_price ep on tr.block_date = ep.day
left join eth_gas_price gp on tr.block_date = gp.day
where pb.call_success
    and tr.call_type = 'staticcall'
    -- and pb.call_block_number = 18714103 and pb.call_tx_hash = 0x907bb8859d085d9c36c3ac15bed76d1c4beb771137a64012c397a83a03614f43
group by 1 

union all 

/* post-Boojum: 0xa0425d71cB1D6fb80E65a5361a04096E0672De03 (https://zksync.mirror.xyz/HJ2Pj45EJkRdt5Pau-ZXwkV2ctPx8qFL19STM5jdYhc) */
select tr.block_date 
    , count(pb.call_tx_hash) as verifying_calls
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price) as verifying_cost_ETH -- gas in gwei, so divide by 1e9
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price * avg_eth_price) as verifying_cost_usd 
from zksync_v2_ethereum.ValidatorTimelock_call_proveBatches pb 
left join ethereum.traces tr on tr.block_number = pb.call_block_number and tr.tx_hash = pb.call_tx_hash
left join eth_usd_price ep on tr.block_date = ep.day
left join eth_gas_price gp on tr.block_date = gp.day
where pb.call_success
    and tr.call_type = 'staticcall'
    -- and pb.call_block_number = 19187874 and pb.call_tx_hash = 0xc34c48710ddc81c2920b1f3ddb1476bd3bb448f15c0eb93ba52909d782a6d5d0
group by 1 

union all 

/* post-EIP4844: 0xa8CB082A5a689E0d594d7da1E2d72A3D63aDc1bD */
select tr.block_date 
    , count(pb.call_tx_hash) as verifying_calls
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price) as verifying_cost_ETH -- gas in gwei, so divide by 1e9
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price * avg_eth_price) as verifying_cost_usd 
from zksync_v2_ethereum.ValidatorTimelock3_call_proveBatches pb 
left join ethereum.traces tr on tr.block_number = pb.call_block_number and tr.tx_hash = pb.call_tx_hash
left join eth_usd_price ep on tr.block_date = ep.day
left join eth_gas_price gp on tr.block_date = gp.day
where pb.call_success
    and tr.call_type = 'staticcall'
    -- and pb.call_block_number = 19592389 and pb.call_tx_hash = 0x8c82e4e130094c5ff78c719aaf53c2aad21a7a92da921df1083d74f4f5f766aa
group by 1 

union all 

/* post v24 upgrade (shared bridge): 0x5D8ba173Dc6C3c90C8f7C04C9288BeF5FDbAd06E
    - temporarily matching on transactions and method id until contract decdoed 
*/
select tr.block_date 
    , count(distinct tr.tx_hash) as verifying_calls
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price) as verifying_cost_ETH -- gas in gwei, so divide by 1e9
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price * avg_eth_price) as verifying_cost_usd 
from ethereum.transactions t
join ethereum.traces tr on tr.tx_hash = t.hash and t.block_number = tr.block_number
left join eth_usd_price ep on tr.block_date = ep.day
left join eth_gas_price gp on tr.block_date = gp.day
where t.success
    and t.to in (
        0x5D8ba173Dc6C3c90C8f7C04C9288BeF5FDbAd06E
    )
    and bytearray_substring(t.data, 1, 4) = 0xc37533bb -- proveBatchesSharedBridge
    and tr.call_type = 'staticcall'
    and tr.to = 0x70f3fbf8a427155185ec90bed8a3434203de9604 -- temporarily doing this until we have correct internal transactions for precompiles
    -- and tr.block_number = 20034517 and tr.tx_hash = 0x5ed81fc4cfd813102a502a6fb5e66864bb341a1ce2c0d1cc65d34b53b38e53d3
group by 1  1 