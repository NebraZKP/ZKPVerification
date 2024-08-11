-- part of a query repo
-- query name: zksync era verification base
-- query link: https://dune.com/queries/3890722

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
    /* pre-Boojum: 0x3dB52cE065f728011Ac6732222270b3F2360d919 */
    select distinct tr.block_number, tr.block_date, tr.tx_hash, tr.gas_used, tr.call_type
    from zksync_v2_ethereum.ValidatorTimelock_call_proveBlocks pb 
    left join ethereum.traces tr on tr.block_number = pb.call_block_number and tr.tx_hash = pb.call_tx_hash
    where pb.call_success
        and tr.call_type = 'staticcall' -- assuming that verifier contract should be called as readonly staticcalls (next best to identifying all verifier contracts which is pretty impossible manually)
        -- and pb.call_block_number = 18714103 and pb.call_tx_hash = 0x907bb8859d085d9c36c3ac15bed76d1c4beb771137a64012c397a83a03614f43
    
    UNION ALL
    
    /* post-Boojum: 0xa0425d71cB1D6fb80E65a5361a04096E0672De03 (https://zksync.mirror.xyz/HJ2Pj45EJkRdt5Pau-ZXwkV2ctPx8qFL19STM5jdYhc) */
    select distinct tr.block_number, tr.block_date, tr.tx_hash, tr.gas_used, tr.call_type
    from zksync_v2_ethereum.ValidatorTimelock_call_proveBatches pb 
    left join ethereum.traces tr on tr.block_number = pb.call_block_number and tr.tx_hash = pb.call_tx_hash
    where pb.call_success
        and tr.call_type = 'staticcall' -- assuming that verifier contract should be called as readonly staticcalls (next best to identifying all verifier contracts which is pretty impossible manually)
        -- and pb.call_block_number = 19187874 and pb.call_tx_hash = 0xc34c48710ddc81c2920b1f3ddb1476bd3bb448f15c0eb93ba52909d782a6d5d0
    
    UNION ALL 
    
    /* post-EIP4844: 0xa8CB082A5a689E0d594d7da1E2d72A3D63aDc1bD */
    select distinct tr.block_number, tr.block_date, tr.tx_hash, tr.gas_used, tr.call_type
    from zksync_v2_ethereum.ValidatorTimelock3_call_proveBatches pb 
    left join ethereum.traces tr on tr.block_number = pb.call_block_number and tr.tx_hash = pb.call_tx_hash
    where pb.call_success
        and tr.call_type = 'staticcall' -- assuming that verifier contract should be called as readonly staticcalls (next best to identifying all verifier contracts which is pretty impossible manually)
        -- and pb.call_block_number = 19592389 and pb.call_tx_hash = 0x8c82e4e130094c5ff78c719aaf53c2aad21a7a92da921df1083d74f4f5f766aa
    
    UNION ALL 
    
    /* post v24 upgrade (shared bridge): 0x5D8ba173Dc6C3c90C8f7C04C9288BeF5FDbAd06E
    */
    select distinct tr.block_number, tr.block_date, tr.tx_hash, tr.gas_used, tr.call_type
    from zksync_v3_ethereum.ValidatorTimelock_call_proveBatchesSharedBridge pb 
    left join ethereum.traces tr on tr.block_number = pb.call_block_number and tr.tx_hash = pb.call_tx_hash
    where pb.call_success
        and tr.call_type = 'staticcall' -- assuming that verifier contract should be called as readonly staticcalls (next best to identifying all verifier contracts which is pretty impossible manually)
        -- and tr.block_number = 20034517 and tr.tx_hash = 0x5ed81fc4cfd813102a502a6fb5e66864bb341a1ce2c0d1cc65d34b53b38e53d3
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
group by 1 