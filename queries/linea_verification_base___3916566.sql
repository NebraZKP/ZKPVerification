-- part of a query repo
-- query name: Linea verification base
-- query link: https://dune.com/queries/3916566


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
    -- tr.*
    tr.block_date 
    , count(distinct tx_hash) as verifying_calls
    , sum(case when tx.type = 'Legacy' then cast(tr.gas_used as double) * median_legacy_gas_price -- legacy
        when tx.type = 'DynamicFee' then cast(tr.gas_used as double) * median_dynamic_gas_price -- dynamic 
        -- should only be these 2 txn types, blob and AccessList don't apply 
    end) as verifying_cost_ETH
    , sum(case when tx.type = 'Legacy' then cast(tr.gas_used as double) * median_legacy_gas_price * avg_eth_price -- legacy
        when tx.type = 'DynamicFee' then cast(tr.gas_used as double) * median_dynamic_gas_price * avg_eth_price -- dynamic 
    end) as verifying_cost_usd
from ethereum.transactions tx 
left join ethereum.traces tr on tr.block_number = tx.block_number and tr.tx_hash = tx.hash
left join eth_usd_price ep on tr.block_date = ep.day
left join eth_gas_price gp on tr.block_date = gp.day
WHERE tx.to = 0xd19d4B5d358258f05D7B411E21A1460D11B0876F -- Linea L1 Message Service
        AND (bytearray_substring(tx.data, 1, 4) = 0xd630280f -- finalizeCompressedBlocksWithProof -- https://etherscan.io/tx/0xdfd79401c75f370e4a742223c1f553d934ec6903106cde1f1b6814dc5825bb15/advanced#internal
            OR bytearray_substring(tx.data, 1, 4) = 0x4165d6dd -- finalizeBlocks (old contract) -- https://etherscan.io/tx/0x750cf2a6239e1fee1f04b6d66fa93822ce2b4ae4d81e84035f1dc313391e512a/advanced#internal
            OR bytearray_substring(tx.data, 1, 4) = 0x5603c65f -- finalizeBlocks (current contract) -- https://etherscan.io/tx/0x006a303e87fef08c09f35a83c535e916e990e1f115d420a768499dac46a28627/advanced
            OR bytearray_substring(tx.data, 1, 4) = 0xabffac32 -- finalizeBlocksWithProof -- https://etherscan.io/tx/0x11a41718c21e2aa3c7052b99938b26ac366a30ba00aad0a7b5dff63bfe0309b1/advanced#internal
            )
    and tr.to in ( -- Verifier contracts
        select ct.address as plonk_verifier
        from ethereum.transactions tx
        left join ethereum.creation_traces ct on ct.block_number = tx.block_number and ct.tx_hash = tx.hash
        where tx."from" = 0x6dD3120E329dC5FaA3d2Cf65705Ef4f6486F65F7
            and bytearray_substring(tx.data, 1, 4) = 0x60806040
        ) 
    -- and tx.block_date >= now() - interval '7' day
    -- and tx.block_number = 19853383 and tx.hash = 0xdfd79401c75f370e4a742223c1f553d934ec6903106cde1f1b6814dc5825bb15 -- https://etherscan.io/tx/0xdfd79401c75f370e4a742223c1f553d934ec6903106cde1f1b6814dc5825bb15/advanced#internal
group by 1