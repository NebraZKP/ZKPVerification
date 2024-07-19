-- part of a query repo
-- query name: ZKP all time all project
-- query link: https://dune.com/queries/3919405


with base as (
    -- infra/rollup
    select 'infra' as type, 'Ethereum' as chain, 'zkSync Era' as protocol, * from dune.nebra.result_zksync_era_verification_base -- https://dune.com/queries/3890722
    UNION ALL
    select 'infra' as type, 'Ethereum' as chain, 'Scroll' as protocol, * from dune.nebra.result_scroll_verification_base -- https://dune.com/queries/3916549
    UNION ALL
    select 'infra' as type, 'Ethereum' as chain, 'Linea' as protocol, * from dune.nebra.result_linea_verification_base -- https://dune.com/queries/3916566
    UNION ALL
    select 'infra' as type, 'Ethereum' as chain, 'Loopring' as protocol, * from dune.nebra.result_loopring_verfication_base -- https://dune.com/queries/3902706
    UNION ALL
    select 'infra' as type, 'Ethereum' as chain, 'Aztec' as protocol, * from dune.nebra.result_aztec_verification_base -- https://dune.com/queries/3916310
    UNION ALL
    select 'infra' as type, 'Ethereum' as chain, 'Polygon zkEVM' as protocol, * from dune.nebra.result_polygon_zk_evm_verification_base -- https://dune.com/queries/3916389
    
    -- app
    UNION ALL
    select 'app' as type, 'Ethereum' as chain, 'dYdX (StarkEx)' as protocol, * from dune.nebra.result_dydx_stark_ex_verification_base -- https://dune.com/queries/3902468
    UNION ALL
    select 'app' as type, 'Ethereum' as chain, 'Tornado Cash' as protocol, * from dune.nebra.result_tornado_cash_verification_base -- https://dune.com/queries/3902791
    UNION ALL
    select 'app' as type, 'Ethereum' as chain, 'Nocturne' as protocol, * from dune.nebra.result_nocturne_verification_base -- https://dune.com/queries/3916443
    UNION ALL
    select 'app' as type, 'Ethereum' as chain, 'Railgun' as protocol, * from dune.nebra.result_railgun_verification_base -- https://dune.com/queries/3902794
    
    -- exclude because it's on OP/L2
    -- select 'infra' as type, 'Ethereum' as chain, 'Worldcoin' as protocol, * from dune.nebra.result_worldcoin_op_verification_base -- https://dune.com/queries/3902422

)

select sum(verifying_cost_usd) as total_zkp_cost_usd
    , sum(verifying_cost_ETH) as total_zkp_cost_eth
    , sum(verifying_calls) as total_zkp_txns
    , array_agg(distinct protocol) as coverage_projects
    , count(distinct protocol) as coverage_num
from base