-- FORK
-- part of a query repo
-- query name: Scroll verification base
-- query link: https://dune.com/queries/3916549


with eth_usd_price as (
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
    , sum(cast(tr.gas_used as double) * tx.gas_price / 1e18) as verifying_cost_ETH -- gas_price column already account for dynamic txn so we can use it as is
    , sum(cast(tr.gas_used as double) * tx.gas_price / 1e18 * avg_eth_price) as verifying_cost_usd
from ethereum.transactions tx
left join ethereum.traces tr on tr.block_number = tx.block_number and tr.tx_hash = tx.hash
left join eth_usd_price ep on tr.block_date = ep.day
where 1=1
    -- and varbinary_substring(tx.data, 1, 4) = 0x00b0f4d7 -- finalizeBatchWithProof4844, not needed
    and tx."from" in (
        0x356483dC32B004f32Ea0Ce58F7F88879886e9074, -- old batch finalizer, per Scroll team this is the correct address
        0x6f9d816c4ec365fe8fc6898c785be0e2d51bec2c -- current batch finalizer https://etherscan.io/accounts/label/scroll
    )
    and tr.to in ( -- filter for calls to the actual proof verifier 
        0x4B8Aa8A96078689384DAb49691E9bA51F9d2F9E1 -- L1_PLONK_VERIFIER_V0_ADDR
        , 0x2293cd12e8564e8219d314b075867c2f66ac6941 -- L1_PLONK_VERIFIER_V1_ADDR
        , 0x03a72B00D036C479105fF98A1953b15d9c510110 -- L1_PLONK_VERIFIER_V2_ADDR
        , 0x8759E83b6570A0bA46c3CE7eB359F354F816c9a9 -- L1_PLONK_VERIFIER_V3_ADDR
        , 0x8c1b52757b5c571ADcB5572E992679d4D48e30f7 -- L1_PLONK_VERIFIER_V4_ADDR
    )
    and tr.call_type = 'staticcall' -- assuming that verifier contract should be called as readonly staticcalls (next best to identifying all verifier contracts which is pretty impossible manually)
    
    -- and tx.block_date >= now() - interval '7' day
    -- and tx.block_number = 20301391 and tx.hash = 0x59fd8268be53ba38b267696270e3a09d2768036295552f19ca5edc607a3faa41 -- https://etherscan.io/tx/0x59fd8268be53ba38b267696270e3a09d2768036295552f19ca5edc607a3faa41/advanced#internal --> 200,549
group by 1izer, per Scroll team this is the correct address
    and tr.call_type = 'staticcall' -- assuming that verifier contract should be called as readonly staticcalls (next best to identifying all verifier contracts which is pretty impossible manually)
    
    -- and tx.block_date >= now() - interval '7' day
    -- and tx.block_number = 20301391 and tx.hash = 0x59fd8268be53ba38b267696270e3a09d2768036295552f19ca5edc607a3faa41 -- https://etherscan.io/tx/0x59fd8268be53ba38b267696270e3a09d2768036295552f19ca5edc607a3faa41/advanced#internal --> 200,549
group by 1