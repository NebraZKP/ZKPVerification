-- part of a query repo
-- query name: Linea verification base
-- query link: https://dune.com/queries/3916566


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
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price) as verifying_cost_ETH -- gas in gwei, so divide by 1e9
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price * avg_eth_price) as verifying_cost_usd 
from ethereum.transactions tx 
left join ethereum.traces tr on tr.block_number = tx.block_number and tr.tx_hash = tx.hash
left join eth_usd_price ep on tr.block_date = ep.day
left join eth_gas_price gp on tr.block_date = gp.day
WHERE tx.to = 0xd19d4B5d358258f05D7B411E21A1460D11B0876F -- Linea L1 Message Service
        AND (bytearray_substring(tx.data, 1, 4) = 0xd630280f -- finalizeCompressedBlocksWithProof -- https://etherscan.io/tx/0xdfd79401c75f370e4a742223c1f553d934ec6903106cde1f1b6814dc5825bb15/advanced#internal
            OR bytearray_substring(tx.data, 1, 4) = 0x4165d6dd -- finalizeBlocks -- https://etherscan.io/tx/0x750cf2a6239e1fee1f04b6d66fa93822ce2b4ae4d81e84035f1dc313391e512a/advanced#internal
            OR bytearray_substring(tx.data, 1, 4) = 0xabffac32 -- finalizeBlocksWithProof -- https://etherscan.io/tx/0x11a41718c21e2aa3c7052b99938b26ac366a30ba00aad0a7b5dff63bfe0309b1/advanced#internal
            )
    and tr.to in (0xc01E6807DB9Fb9cC75E9Fe622ba8e7f3eB9f2B32, 0x6312e56c17e1011dd0821558034a77bb60d06e1b, 0x8AB455030E1Ea718e445f423Bb8D993dcAd24Cc4) -- PlonkVerifierFull
    -- and tx.block_number = 19853383 and tx.hash = 0xdfd79401c75f370e4a742223c1f553d934ec6903106cde1f1b6814dc5825bb15 -- https://etherscan.io/tx/0xdfd79401c75f370e4a742223c1f553d934ec6903106cde1f1b6814dc5825bb15/advanced#internal
group by 1