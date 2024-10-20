-- part of a query repo
-- query name: Worldcoin Mainnet verification base
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
    tr.block_date
    , count(distinct tx_hash) as verifying_calls
    , sum(case when tx.type = 'DynamicFee' then cast(tr.gas_used as double) * median_dynamic_gas_price -- dynamic 
        else cast(tr.gas_used as double) * median_legacy_gas_price -- legacy
    end) as verifying_cost_ETH
    , sum(case when tx.type = 'DynamicFee' then cast(tr.gas_used as double) * median_dynamic_gas_price * avg_eth_price -- dynamic 
        else cast(tr.gas_used as double) * median_legacy_gas_price * avg_eth_price -- legacy
    end) as verifying_cost_usd
from
ethereum.transactions tx
left join ethereum.traces tr on tr.block_number = tx.block_number
and tr.tx_hash = tx.hash
left join eth_usd_price ep on tr.block_date = ep.day
left join eth_gas_price gp on tr.block_date = gp.day
where
    tx.to = 0xf7134ce138832c1456f2a91d64621ee90c2bddea -- WorldIDIdentityManager
    and tr.to in (
        0xb5f23A0c92F2f4aeE506FA3B1Cc2813820d13258, -- size 100 register verifier
        0xFC1c26E964F791f81a33F49D91f79456891AA1c1, -- size 600 register verifier
        0xE44c83b9e1971A24EC698829297A0C4026B0CeF9, -- size 1200 register verifier
        0xCA7d6822b9c6913B1A1416cE30eF14c4e7f0bFb1, -- size 10 delete verifier
        0x43B68ccBa7FC726540768fD1537c3179283140ed -- size 100 delete verifier
    )
    and bytearray_substring (tr.input, 1, 4) in (
        0x1b81f829, -- verifyProof
        0x9bcbaf09 -- verifyCompressedProof
    )
    and tx.block_number > 17636831 -- WorldIDIdentityManager deployed at block 17636832
group by 1
