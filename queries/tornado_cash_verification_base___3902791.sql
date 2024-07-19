-- part of a query repo
-- query name: tornado cash verification base
-- query link: https://dune.com/queries/3902791


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

select tr.block_date 
    , count(distinct tx_hash) as verifying_calls
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price) as verifying_cost_ETH -- gas in gwei, so divide by 1e9
    , sum(cast(tr.gas_used as double) / 1e9 * median_gas_price * avg_eth_price) as verifying_cost_usd 
from ethereum.traces tr
left join eth_usd_price ep on tr.block_date = ep.day
left join eth_gas_price gp on tr.block_date = gp.day
where tr.to = 0xce172ce1f20ec0b3728c9965470eaf994a03557a -- Tornado Cash verifier address: https://etherscan.io/address/0xce172ce1f20ec0b3728c9965470eaf994a03557a/advanced#code
    and tr."from" in ( --https://github.com/tornadocash-community/docs/blob/en/general/tornado-cash-smart-contracts.md
        0x12d66f87a04a9e220743712ce6d9bb1b5616b8fc -- 0.1 ETH	
        , 0x47ce0c6ed5b0ce3d3a51fdb1c52dc66a7c3c2936 -- 1 ETH	
        , 0x910cbd523d972eb0a6f4cae4618ad62622b39dbf -- 10 ETH	
        , 0xa160cdab225685da1d56aa342ad8841c3b53f291 -- 100 ETH
        , 0xd4b88df4d29f5cedd6857912842cff3b20c8cfa3 -- 100 DAI
        , 0xfd8610d20aa15b7b2e3be39b396a1bc3516c7144 -- 1,000 DAI	
        , 0x07687e702b410Fa43f4cB4Af7FA097918ffD2730 -- 10,000 DAI	
        , 0x23773E65ed146A459791799d01336DB287f25334 -- 100,000 DAI	
        , 0x22aaA7720ddd5388A3c0A3333430953C68f1849b -- 5,000 cDAI	
        , 0x03893a7c7463AE47D46bc7f091665f1893656003 -- 50,000 cDAI	
        , 0x2717c5e28cf931547B621a5dddb772Ab6A35B701 -- 500,000 cDAI	
        , 0xD21be7248e0197Ee08E0c20D4a96DEBdaC3D20Af -- 5,000,000 cDAI	
        , 0x4736dCf1b7A3d580672CcE6E7c65cd5cc9cFBa9D -- 100 USDC	
        , 0xd96f2B1c14Db8458374d9Aca76E26c3D18364307 -- 1,000 USDC	
        , 0x169AD27A470D064DEDE56a2D3ff727986b15D52B -- 100 USDT	
        , 0x0836222F2B2B24A3F36f98668Ed8F0B38D1a872f -- 1,000 USDT	
        , 0x178169B423a011fff22B9e3F3abeA13414dDD0F1 -- 0.1 WBTC	
        , 0x610B717796ad172B316836AC95a2ffad065CeaB4 -- 1 WBTC	
        , 0xbB93e510BbCD0B7beb5A853875f9eC60275CF498 -- 10 WBTC	
    )
    
-- and block_number = 20252222 and tx_hash = 0xe404161d733877a4fdbf9c315c13e9297604c1829d8db98392cb2120e54566d6

group by 1