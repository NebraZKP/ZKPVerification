-- part of a query repo
-- query name: Railgun verification base
-- query link: https://dune.com/queries/3902794


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

/*
Until Dune indexes internal txns to precompiles, just hardcoding a number from example txns 
https://etherscan.io/tx/0x17487f0634996a2af1206e14d51c0776913f3bb59a15f2d088ddb6355a7cfa8d/advanced#internal
https://etherscan.io/tx/0xed685a840efac778e2e97f47e8af0a5da9414fe1d09b3e6c337ba1be040c11a7/advanced
https://etherscan.io/tx/0xf961c5aee4b000de71c34f075ad1f5b1b3069144283d971e3a924b5083cbd76b/advanced
https://etherscan.io/tx/0xf961c5aee4b000de71c34f075ad1f5b1b3069144283d971e3a924b5083cbd76b/advanced#eventlog
*/

select 
    -- tr.* 
    tr.block_date 
    , count(distinct r.call_tx_hash) as verifying_calls
    , sum(cast(163722.5 as double) / 1e9 * median_gas_price) as verifying_cost_ETH -- gas in gwei, so divide by 1e9
    , sum(cast(163722.5 as double) / 1e9 * median_gas_price * avg_eth_price) as verifying_cost_usd 
from railgun_ethereum.RailgunLogic_call_transact r -- RailgunSmartWallet contract https://etherscan.io/address/0xc0bef2d373a1efade8b952f33c1370e486f209cc
left join ethereum.traces tr on tr.block_number = r.call_block_number and tr.tx_hash = r.call_tx_hash
left join eth_usd_price ep on tr.block_date = ep.day
left join eth_gas_price gp on tr.block_date = gp.day
where r.call_success
    -- and tr.call_type = 'staticcall'
    -- and r.call_block_number = 17519522 and r.call_tx_hash = 0xf961c5aee4b000de71c34f075ad1f5b1b3069144283d971e3a924b5083cbd76b

group by 1




/* gas limit before entering the verifier.sol: 1,320,699 */
/* gas limit after: 899,450*/
/* total spending: 421249 */
/* source: https://etherscan.io/tx/0xf961c5aee4b000de71c34f075ad1f5b1b3069144283d971e3a924b5083cbd76b/advanced#internal */ 
-- RAILGUN AS (
--   SELECT
--     'RAILGUN' AS name,
--     COUNT(*) AS verify_call,
--     ROUND(
--       TRY_CAST(COUNT(*) * 421249 * eth_gas_price * eth_usd AS DECIMAL(38, 10)) / 1000000000.0,
--       4
--     ) AS cost
--   FROM railgun_ethereum.RailgunLogic_call_transact
--   CROSS JOIN ASSUMPTION
--   CROSS JOIN ETH_PRICE
--   CROSS JOIN MATIC_PRICE
--   GROUP BY
--     eth_gas_price,
--     base_verify_cost,
--     eth_usd
-- )