%%%-------------------------------------------------------------------
%%% @author c50 <joq62@c50>
%%% @copyright (C) 2023, c50
%%% @doc
%%%
%%% @end
%%% Created : 21 Jan 2023 by c50 <joq62@c50>
%%%-------------------------------------------------------------------
-module(lib_console).


-export([
	 start_local/0
	 ]).

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
start_local()->
    ok=application:start(common),
    pong=common:ping(),
    ok=application:start(sd),
    pong=sd:ping(),
    ok=application:start(db_etcd),
    pong=db_etcd:ping(),
    ok=db_etcd:config(),
    ok=db_config:create_table(),

    ok=application:start(infra_service),
    pong=infra_service:ping(),
    pong=parent_server:ping(),
    pong=pod_server:ping(),
    pong=appl_server:ping(),
    
    ok.




