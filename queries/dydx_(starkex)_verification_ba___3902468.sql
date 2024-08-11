-- part of a query repo
-- query name: dydx (StarkEx) verification base
-- query link: https://dune.com/queries/3902468


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
/*
Finding dYdX verification contract addresses because the one listed on StarkEx doc I found is not updated 
https://docs.starkware.co/starkex/deployments-addresses.html#dYdX_contracts

select distinct to as dydx_verification_contracts
from ethereum.transactions
where "from" = 0x8129b737912e17212c8693b781928f5d0303390a -- known dYdX: L2 On-Chain Operator
    and varbinary_substring(data, 1, 4) = 0x9b3b76cc -- known verification method verifyProofAndRegister 

resulted
- 0xb1eda32c467569fbdc8c3e041c81825d76b32b84 --> doesn't have to pointing to precompiles and also dates are 1000+ days ago, ignore
- 0xc8c212f11f6acca77a7afeb7282deba5530eb46c -- seems to be older version 
- 0x894c4a12548fb18eaa48cf34f9cd874fc08b7fc3 -- live verification contract
*/


, raw as (
    select distinct tr.*, tx.type as tx_type
    from ethereum.transactions tx 
    left join ethereum.traces tr on tr.block_number = tx.block_number and tr.tx_hash = tx.hash
    where tx.to in( 0xC8c212f11f6ACca77A7afeB7282dEBa5530eb46C, 0x894c4a12548fb18eaa48cf34f9cd874fc08b7fc3) -- see above
        and tx."from" = 0x8129b737912e17212c8693b781928f5d0303390a -- dYdX: L2 On-Chain Operator
        and varbinary_substring(tx.data, 1, 4) = 0x9b3b76cc -- verifyProofAndRegister 
        and tr.call_type = 'staticcall' -- assuming that verifier contract should be called as readonly staticcalls (next best to identifying all verifier contracts which is pretty impossible manually)
        and tr."from" != 0x894c4a12548fb18eaa48cf34f9cd874fc08b7fc3 -- excluding GpsStatementVerifier (assuming it's not part of zkp verification)
        -- and tx.block_number = 17155367 and tx.hash = 0x81d330fc29a007ae5f42d21bfe341b14a229603999024f14e442ac6bd11b7452 
        -- and tx.block_number = 20255425 and tx.hash = 0x08a39734753e63a68eeb2a47060c1c3e1dddf64a34e1f7867f891e30af9a32fc 
)

-- select sum(gas_used) from raw

select  r.block_date 
        , count(distinct r.tx_hash) as verifying_calls
        , sum(case when r.tx_type = 'DynamicFee' then cast(r.gas_used as double) * median_dynamic_gas_price -- dynamic 
            else cast(r.gas_used as double) * median_legacy_gas_price -- legacy
        end) as verifying_cost_ETH
        , sum(case when r.tx_type = 'DynamicFee' then cast(r.gas_used as double) * median_dynamic_gas_price * avg_eth_price -- dynamic 
            else cast(r.gas_used as double) * median_legacy_gas_price * avg_eth_price -- legacy
        end) as verifying_cost_usd
from raw r
left join eth_usd_price ep on r.block_date = ep.day 
left join eth_gas_price gp on r.block_date = gp.day 
-- where r.block_date >= now() - interval '14' day
group by 1 