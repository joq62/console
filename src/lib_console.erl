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
	% initial_start/0,
	 start_local/0,
	 ensure_right_cookie/1,
	 load_desired_states/1,
	 start_parent_nodes/0,
	 start_pod_nodes/0,
	 new_cluster/1
	 
	 
	 ]).

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
new_cluster(ClusterSpec)->
    ok=start_local(),
    ok=load_desired_states(ClusterSpec),
    {ok,_}=start_parent_nodes(),
    {ok,PodDbEtcd}=start_pod("db_etcd"),
    
    ok=start_sd_common(PodDbEtcd),
    ok=start_db_etcd(PodDbEtcd),

    {ok,PodInfra}=start_pod("infra_service"),
    
    ok=start_sd_common(PodInfra),
    ok=start_infra_sevice(PodInfra),
    
    ok.

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------


start_infra_sevice(PodInfra)->
    

    ok.

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
start_db_etcd(DbEtcdNode)->
   
    ok=lib_appl:create_appl("db_etcd",DbEtcdNode),
    false=rpc:call(DbEtcdNode,db_etcd,is_config,[],5000),
    ok=rpc:call(DbEtcdNode,db_etcd,config,[],5000),
    true=rpc:call(DbEtcdNode,db_etcd,is_config,[],5000),
    


    ok.
%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
start_sd_common(Pod)->
    
    ok=lib_appl:create_appl("common",Pod),
    ok=lib_appl:create_appl("sd",Pod),
    %%- On which parent is db_etcd

    ok.

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
start_pod(ApplSpec)->
     A1=[{PodNode,db_pod_desired_state:read(appl_spec_list,PodNode)}||PodNode<-db_pod_desired_state:get_all_id()],
    io:format("A1 ~p~n",[{A1,?MODULE,?FUNCTION_NAME,?LINE}]),
    A2=[{PodNode,ApplList}||{PodNode,{ok,ApplList}}<-A1],
    [Pod]=[Pod||{Pod,ApplList}<-A2,
		      true==lists:member(ApplSpec,ApplList)],
    ok=lib_pod:create_node(Pod),
    
    {ok,Pod}.
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

  %  ok=application:start(infra_service),
  %  pong=infra_service:ping(),
  %  pong=parent_server:ping(),
  %  pong=pod_server:ping(),
  %  pong=appl_server:ping(),
    
    ok.
%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------

				    
%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
ensure_right_cookie(ClusterSpec)->
    Result=case db_cluster_spec:read(cookie,ClusterSpec) of
	       {error,Reason}->
		   {error,[Reason,?MODULE,?LINE]};
	       {ok,Cookie}->
		   erlang:set_cookie(node(),list_to_atom(Cookie)),
		   ok
	   end,
    Result.
%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
load_desired_states(ClusterSpec)->
    ok=db_parent_desired_state:create_table(),
    ok=lib_parent:load_desired_state(ClusterSpec),
    ok=db_pod_desired_state:create_table(),
    ok=lib_pod:load_desired_state(ClusterSpec),
    ok=lib_appl:load_desired_state(ClusterSpec),
     Result=ok,
%    Result=case {Result1,Result2,Result3} of
%	       {ok,ok,ok}->
%		   ok;
%	       _ ->
%		   {error,[" Parent,Pod,Appl : ",Result1,Result2,Result1,?MODULE,?LINE]}
%	   end,
    Result.
%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
start_parent_nodes()->	
    {ok,StoppedParents}=lib_parent:stopped_nodes(),
    _R1=[lib_parent:create_node(Parent)||Parent<-StoppedParents],
    {ok,ActiveParents}=lib_parent:active_nodes(),
    _R=[{net_adm:ping(Pod1),rpc:call(Pod1,net_adm,ping,[Pod2],5000)}||Pod1<-ActiveParents,
							  Pod2<-ActiveParents,
								   Pod1/=Pod2],
    {ok,UpdatedActiveParents}=lib_parent:active_nodes(),
    {ok,UpdatedStoppedParents}=lib_parent:stopped_nodes(),
    {ok,[{active,UpdatedActiveParents},{stopped,UpdatedStoppedParents}]}.
%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
start_pod_nodes()->	
    {ok,StoppedPods}=pod_server:stopped_nodes(),
    _R1=[pod_server:create_node(Pod)||Pod<-StoppedPods],
    {ok,ActivePods}=pod_server:active_nodes(),
    _R=[{net_adm:ping(Pod1),rpc:call(Pod1,net_adm,ping,[Pod2],5000)}||Pod1<-ActivePods,
							  Pod2<-ActivePods,
								   Pod1/=Pod2],
    {ok,UpdatedActivePods}=pod_server:active_nodes(),
    {ok,UpdatedStoppedPods}=pod_server:stopped_nodes(),
    {ok,[{active,UpdatedActivePods},{stopped,UpdatedStoppedPods}]}.

    
%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------

create_appl(WantedApp)->
    {ok,StoppedApplInfoLists}=appl_server:stopped_appls(),   
    Stopped=[{PodNode,ApplSpec,App}||{PodNode,ApplSpec,App}<-StoppedApplInfoLists,
					   WantedApp==App],
    StartResult=[{error,Reason}||{error,Reason}<-create_appl(Stopped,[])],
    Result=case StartResult of
	       []->
		   ok;
	       StartResult->
		   {error,["Couldnt create Appl : ",WantedApp,?MODULE,?FUNCTION_NAME,?LINE]}
	   end,
    Result.

create_appl([],Acc)->
    Acc;
create_appl([{PodNode,ApplSpec,App}|T],Acc)->
    Result=appl_server:create_appl(ApplSpec,PodNode),
    io:format("Creat Appl Result ~p~n",[{Result,PodNode,ApplSpec,?MODULE,?FUNCTION_NAME,?LINE}]),
    create_appl(T,[{Result,PodNode,ApplSpec,App}|Acc]).
    

