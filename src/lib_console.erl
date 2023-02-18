%%%-------------------------------------------------------------------
%%% @author c50 <joq62@c50>
%%% @copyright (C) 2023, c50
%%% @doc
%%%
%%% @end
%%% Created : 21 Jan 2023 by c50 <joq62@c50>
%%%-------------------------------------------------------------------
-module(lib_console).

-define(LogDir,"log_dir").
-define(LogFileName,"file.logs").


-export([
	 new_cluster/1
	 
	 
	 ]).

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
new_cluster(ClusterSpec)->

    ok=start_local_appls(),
    ok=initiate_local_dbase(ClusterSpec),
    ok=ensure_right_cookie(ClusterSpec),
    
    {ok,ActiveParents}=start_parents(),
    io:format("ActiveParents !!! ~p~n",[{ActiveParents,?MODULE,?FUNCTION_NAME}]),

    %%-- create nodelog appl
  
    [{ok,NodelogPod,_NodelogApplSpec}]=lib_infra_service:create_pods_based_appl("nodelog"),
    [{ok,_,_,_}]=lib_infra_service:create_appl([{NodelogPod,"common",common}]),
    [{ok,_,_,_}]=lib_infra_service:create_appl([{NodelogPod,"sd",sd}]),
    ok=lib_infra_service:create_infra_appl({NodelogPod,"nodelog",nodelog},ClusterSpec),
    io:format("Phase 1 Running nodes !!! ~p~n",[{running_nodes(NodelogPod),?MODULE,?FUNCTION_NAME}]),
    io:format("Phase 1 Running apps !!! ~p~n",[{running_apps(NodelogPod),?MODULE,?FUNCTION_NAME}]),

    %%-- create db_etcd
    [{ok,DbPod,_DbApplSpec}]=lib_infra_service:create_pods_based_appl("db_etcd"),
    [{ok,_,_,_}]=lib_infra_service:create_appl([{DbPod,"common",common}]),
    [{ok,_,_,_}]=lib_infra_service:create_appl([{DbPod,"sd",sd}]),
    ok=lib_infra_service:create_infra_appl({DbPod,"db_etcd",db_etcd},ClusterSpec),
    application:stop(db_etcd),
    [DbPod]=sd:get_node(db_etcd),
    io:format("DbPod ~p~n",[{DbPod,?MODULE,?FUNCTION_NAME,?LINE}]),
    %%- Initiate db_etcd with desired_State !!
    
    ok=parent_server:load_desired_state(ClusterSpec),
    ok=pod_server:load_desired_state(ClusterSpec),
    ok=appl_server:load_desired_state(ClusterSpec),

  %%-- create infra_service
    [{ok,InfraPod,InfraApplSpec}]=lib_infra_service:create_pods_based_appl("infra_service"),
    [{ok,_,_,_}]=lib_infra_service:create_appl([{InfraPod,"common",common}]),
    [{ok,_,_,_}]=lib_infra_service:create_appl([{InfraPod,"sd",sd}]),
    ok=lib_infra_service:create_infra_appl({InfraPod,"infra_service",infra_service},ClusterSpec),
    true=rpc:cast(InfraPod,infra_service,start_orchistrate,[]),
    

    
    io:format("Phase 3 Running nodes !!! ~p~n",[{running_nodes(NodelogPod),?MODULE,?FUNCTION_NAME}]),
    io:format("Phase 3 Running apps !!! ~p~n",[{running_apps(NodelogPod),?MODULE,?FUNCTION_NAME}]),

    WhichApplications2=[{Node,rpc:call(Node,application,which_applications,[],5000)}||Node<-nodes()],
    io:format("WhichApplications2 !!! ~p~n",[{WhichApplications2,?MODULE,?FUNCTION_NAME,?LINE}]),
    
       
    ok.


%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
start_local_appls()->
    io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME}]),

    ok=application:start(common),
    ok=application:start(sd),
    ok=application:start(db_etcd),
    pong=db_etcd:ping(),
    ok=db_etcd:config(),
    
    ok=application:start(infra_service),
    pong=parent_server:ping(),
    pong=pod_server:ping(),
    pong=appl_server:ping(),

    ok.

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
start_parents()->
    io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME}]),

    % just for testing 
    [rpc:call(Pod,init,stop,[],5000)||Pod<-db_parent_desired_state:get_all_id()],
    timer:sleep(2000),
    [rpc:call(Pod,init,stop,[],5000)||Pod<-db_pod_desired_state:get_all_id()],
    timer:sleep(1000),
    %------------------
    {ok,StoppedParents}=parent_server:stopped_nodes(),
    StartParents=[{parent_server:create_node(Parent),Parent}||Parent<-StoppedParents],

    io:format("StartParents ~p~n",[{StartParents,?MODULE,?LINE}]),

    {ok,ActiveParents}=parent_server:active_nodes(),
    _=[{net_adm:ping(Pod1),rpc:call(Pod1,net_adm,ping,[Pod2],5000)}||Pod1<-ActiveParents,
								   Pod2<-ActiveParents,
								   Pod1/=Pod2],
    {ok,ActiveParents}.


%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
initiate_local_dbase(ClusterSpec)->
    io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME}]),
    ok=parent_server:load_desired_state(ClusterSpec),
    ok=pod_server:load_desired_state(ClusterSpec),
    ok=appl_server:load_desired_state(ClusterSpec),	
    
    
    ok.

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
ensure_right_cookie(ClusterSpec)->
    io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME}]),
    {ok,Cookie}=db_cluster_spec:read(cookie,ClusterSpec),
    erlang:set_cookie(node(),list_to_atom(Cookie)),
    
    ok.
%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
running_apps(Node)->
    Nodes=lists:delete(node(),[Node|rpc:call(Node,erlang,nodes,[],5000)]),
    running_apps(Nodes,[]).

running_apps([],Acc)->
    Acc;
running_apps([Node|T],Acc)->
    AppInfo=[{App,Info,Vsn}||{App,Info,Vsn}<-rpc:call(Node,application,which_applications,[],5000),
			     stdlib/=App,
			     kernel/=App],
    running_apps(T,[{Node,AppInfo}|Acc]).
    


running_nodes(Node)->
    
    lists:delete(node(),[Node|rpc:call(Node,erlang,nodes,[],5000)]).
