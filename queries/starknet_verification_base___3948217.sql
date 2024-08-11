-- part of a query repo
-- query name: Starknet verification base
-- query link: https://dune.com/queries/3948217

/* https://community.starknet.io/t/starknet-costs-and-fees/113853#fixed-per-sharp-train-7
- from above post, cost of each SHARP train is fixed at 6M
    -> multiply the VerifyProofAndRegister tx for the verfier (https://etherscan.io/address/0x47312450b3ac8b5b8e247a6bb6d523e7605bdb60) by 6M gas - and then mutiply it by 0.7 (that is a rough estimation of Starknets share in the shared proof).
    - cost of each starknet block is 215k 
        -> Multiply the updateStateKzgDA or Update State to the Starknet core contract (https://etherscan.io/address/0xc662c410c0ecf747543f5ba90660f6abebd9c8c4) that will give you the amount of blocks in each train - you can multiply that number by the variable cost that each block has 215K
        
- starknet's own report on cost: https://console.cloud.google.com/storage/browser/starknet-sharp-bi-public-buckets/files/namespace%3Dsharp5-production-bi/daily_reports/gcp-starknet-production_starknet-mainnet;tab=objects?prefix=&forceOnObjectsSortingFiltering=false
*/

with eth_gas_price as (
    SELECT DATE_TRUNC('day', block_time) AS day
        , APPROX_PERCENTILE(cast(gas_price as double), 0.5) AS median_gas_price
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


select tx.block_date 
    , count(distinct tx.hash) as verifying_calls
    , sum(case when tx.type = 'Legacy' then 6000000 * 0.7 / 1e18 * median_gas_price -- legacy
        when tx.type = 'DynamicFee' then 6000000 * 0.7 / 1e18 * (b.base_fee_per_gas + tx.priority_fee_per_gas) -- dynamic 
        -- should only be these 2 txn types, blob and AccessList don't apply 
    end) as verifying_cost_ETH
    , sum(case when tx.type = 'Legacy' then 6000000 * 0.7 / 1e18 * median_gas_price * avg_eth_price -- legacy
        when tx.type = 'DynamicFee' then 6000000 * 0.7 / 1e18 * (b.base_fee_per_gas + tx.priority_fee_per_gas) * avg_eth_price -- dynamic 
    end) as verifying_cost_usd
from ethereum.transactions tx 
INNER JOIN ethereum.blocks b ON tx.block_number = b.number
left join eth_usd_price ep on tx.block_date = ep.day
left join eth_gas_price gp on tx.block_date = gp.day
where tx.to = 0x47312450B3Ac8b5b8e247a6bB6d523e7605bDb60 -- Starknet verifier address on ETH Mainnet https://docs.starknet.io/tools/important-addresses/#starknet_on_mainnet
    and varbinary_substring(tx.data, 1, 4) = 0x9b3b76cc -- verifyProofAndRegister
    -- and tx.block_date >= now() - interval '7' day
    -- and tx.block_number = 20404091 and tx.hash = 0xd37f8d75c0f605b4c8f482014c3b34209f5ee1bea6b520ae8122973add239459
group by 1