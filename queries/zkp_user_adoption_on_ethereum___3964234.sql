-- part of a query repo
-- query name: ZKP User Adoption on Ethereum
-- query link: https://dune.com/queries/3964234


with base as (
    select date_trunc('month', block_time) as period
        , 'infra' as type
        , 'Scroll' as protocol
        , count(distinct "from") as active_addresses
    from scroll.transactions r
    group by 1,2,3
    
    UNION ALL 
    
    select date_trunc('month', block_time) as period
        , 'infra' as type
        , 'Polygon zkEVM' as protocol
        , count(distinct "from") as active_addresses
    from zkevm.transactions r
    group by 1,2,3
    
    UNION ALL 
    
    select date_trunc('month', block_time) as period
        , 'infra' as type
        , 'Linea' as protocol
        , count(distinct "from") as active_addresses
    from linea.transactions r
    group by 1,2,3
    
    UNION ALL 
    
    select date_trunc('month', block_time) as period
        , 'infra' as type
        , 'zkSync Era' as protocol
        , count(distinct "from") as active_addresses
    from zksync.transactions r
    group by 1,2,3
    
    UNION ALL 
    
    select date_trunc('month', block_time) as period
        , 'infra' as type
        , 'Starknet' as protocol
        , count(distinct sender_address) as active_addresses
    from starknet.transactions r
    group by 1,2,3
    
    UNION ALL 
    
    select date_trunc('month', date("date")) as period
        , 'infra' as type
        , 'Loopring' as protocol
        , ceiling(sum(daa) * 0.5) as active_addresses -- we are overcounting because data pulled is daily, so there will be dupes, I'm putitng a dampening effect by * 0.5 until we get proper data
        -- , approx_percentile(daa, 0.8) as active_addresses 
    from dune.nebra.dataset_loopring_daa
    group by 1,2,3
    
    UNION ALL
    
    select date_trunc('month', tr.block_time) as period
        , 'app' as type
        , 'Nocturne' as protocol
        , count(distinct tr."from") as active_addresses
    from ethereum.traces tr
    where "from" in (
        select address---, name, namespace, detection_source, created_at
        from ethereum.contracts
        where namespace = 'nocturne'
    )
    group by 1,2,3
    
    UNION ALL
    
    select date_trunc('month', tr.block_time) as period
        , 'app' as type
        , 'Railgun' as protocol
        , count(distinct tr."from") as active_addresses
    from ethereum.traces tr
    where "from" in (
        select address---, name, namespace, detection_source, created_at
        from ethereum.contracts
        where namespace = 'railgun'and name != 'RailToken' -- excluding all the activities on the ERC20 tokens
    )
    group by 1,2,3

    UNION ALL
    
    select date_trunc('month', tr.block_time) as period
        , 'app' as type
        , 'Tornado Cash' as protocol
        , count(distinct tr."from") as active_addresses
    from ethereum.traces tr
    where "from" in (
        select address---, name, namespace, detection_source, created_at
        from ethereum.contracts
        where namespace in ('tornado_cash', 'tornado_cash_nova') and name != 'TORN' -- excluding all the activities on the ERC20 tokens
    )
    group by 1,2,3
)

select period, type, protocol, active_addresses
from base
where period >= now() - interval '4' year
order by period, protocol