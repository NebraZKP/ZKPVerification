-- part of a query repo
-- query name: Starknet verification base
-- query link: https://dune.com/queries/3948217

--  https://community.starknet.io/t/starknet-costs-and-fees/113853#fixed-per-sharp-train-7

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


select tr.block_date 
, count(distinct tx_hash) as verifying_calls
, sum(6000000 / 1e9 * median_gas_price) as verifying_cost_ETH -- gas in gwei, so divide by 1e9
, sum(6000000 / 1e9 * median_gas_price * avg_eth_price) as verifying_cost_usd 
from ethereum.transactions tx 
left join ethereum.traces tr on tr.block_number = tx.block_number and tr.tx_hash = tx.hash
left join eth_usd_price ep on tr.block_date = ep.day
left join eth_gas_price gp on tr.block_date = gp.day
where tx.to = 0x47312450B3Ac8b5b8e247a6bB6d523e7605bDb60 -- Starknet verifier address on ETH Mainnet https://docs.starknet.io/tools/important-addresses/#starknet_on_mainnet
    and varbinary_substring(tx.data, 1, 4) = 0x9b3b76cc -- verifyProofAndRegister
    -- and tr.call_type = 'staticcall' 
    -- and tx.block_number = 20404091 and tx.hash = 0xd37f8d75c0f605b4c8f482014c3b34209f5ee1bea6b520ae8122973add239459
group by 1
14c3b34209f5ee1bea6b520ae8122973add239459
group by 1
