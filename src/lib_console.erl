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
	 start_local/0,
	 ensure_right_cookie/1,
	 initiate_local_dbase/1,
	 start_parent_nodes/0,
	 start_pod_nodes/0,
	 new_cluster/1
	 
	 
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
%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
new_cluster(ClusterSpec)->
    Result=case ensure_right_cookie(ClusterSpec) of
	       {error,Reason}->
		   {error,["Couldnt set right cookie : ",Reason,?MODULE,?LINE]};
	       ok->
		   case initiate_local_dbase(ClusterSpec) of
		       {error,Reason}->
			   {error,["Couldnt initiate local db_etcd : ",Reason,?MODULE,?LINE]};
		       ok->
			   case start_parent_nodes() of
			       {error,Reason}->
				   {error,["Couldnt start parent nodes : ",Reason,?MODULE,?LINE]};
			       {ok,_}->
				   case start_parent_nodes() of
				       {error,Reason}->
					   {error,["Couldnt start pod nodes : ",Reason,?MODULE,?LINE]};
				       {ok,_}->
					   case create_appl(common) of
					       {error,Reason}->
						   {error,["Couldnt start common  : ",Reason,?MODULE,?LINE]};
					       ok->
						   case create_appl(sd) of
						       {error,Reason}->
							   {error,["Couldnt start sd  : ",Reason,?MODULE,?LINE]};
						       ok->
							   case create_appl(db_etcd) of
							       {error,Reason}->
								   {error,["Couldnt start db_etcd  : ",Reason,?MODULE,?LINE]};
							       ok->
								   case sd:call(db_etcd,db_etcd,config,[],5000) of
								       {error,Reason}->
									   {error,["Couldnt config db_etcd : ",Reason,?MODULE,?LINE]};
								       ok->
									   case create_appl(nodelog) of
									       {error,Reason}->
										   {error,["Couldnt start nodelog  : ",Reason,?MODULE,?LINE]};
									       ok->
										   {ok,ActiveApplsInfoListNodelog}=appl_server:active_appls(),
										   true=lists:keymember(nodelog,3,ActiveApplsInfoListNodelog),
										   [{NodelogNode,NodelogApp}]=[{Node,App}||{Node,_ApplSpec,App}<-ActiveApplsInfoListNodelog,
															   nodelog==App],
										   IsConfig=sd:call(nodelog,nodelog,is_config,[],5000),
										   if
										       IsConfig=:=false->
											   {ok,PodDir}=db_pod_desired_state:read(pod_dir,NodelogNode),
											   PathLogDir=filename:join(PodDir,?LogDir),
											   rpc:call(NodelogNode,file,del_dir_r,[PathLogDir],5000),
											   ok=rpc:call(NodelogNode,file,make_dir,[PathLogDir],5000),
											   PathLogFile=filename:join([PathLogDir,?LogFileName]),
											   ok=rpc:call(NodelogNode,NodelogApp,config,[PathLogFile],5000),
											   true=rpc:call(NodelogNode,NodelogApp,is_config,[],5000),
											   ok=application:stop(db_etcd);
										       true ->
											   ok
										   end,
										   case create_appl(infra_service) of
										       {error,Reason}->
											   {error,["Couldnt start infra_service  : ",Reason,?MODULE,?LINE]};
										       ok->
											   case sd:call(infra_service,infra_service,is_config,[],5000) of
											       true->
												   ok;
											       false->
												   {ok,ActiveApplsInfoListInfraService}=appl_server:active_appls(),
												   true=lists:keymember(infra_service,3,ActiveApplsInfoListInfraService),
												   [{InfraServiceNode,InfraServiceApp}]=[{Node,App}||{Node,_ApplSpec,App}<-ActiveApplsInfoListInfraService,
																	   infra_service==App],
												   
												   ok=rpc:call(InfraServiceNode,InfraServiceApp,config,[ClusterSpec],5000),
												   true=rpc:call(InfraServiceNode,InfraServiceApp,is_config,[],5000),
												   ok
											   end
										   end
									   end
								   end
							   end
						   end
					   end
				   end
			   end
		   end
	   end,
    Result.
					    
				    
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
initiate_local_dbase(ClusterSpec)->
    Result1=parent_server:load_desired_state(ClusterSpec),
    Result2=pod_server:load_desired_state(ClusterSpec),
    Result3=appl_server:load_desired_state(ClusterSpec),	
    Result=case {Result1,Result2,Result3} of
	       {ok,ok,ok}->
		   ok;
	       _ ->
		   {error,[" Parent,Pod,Appl : ",Result1,Result2,Result1,?MODULE,?LINE]}
	   end,
    Result.
%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
start_parent_nodes()->	
    {ok,StoppedParents}=parent_server:stopped_nodes(),
    [ok,ok]=[parent_server:create_node(Parent)||Parent<-StoppedParents],
    {ok,ActiveParents}=parent_server:active_nodes(),
    _R=[{net_adm:ping(Pod1),rpc:call(Pod1,net_adm,ping,[Pod2],5000)}||Pod1<-ActiveParents,
							  Pod2<-ActiveParents,
								   Pod1/=Pod2],
    {ok,UpdatedActiveParents}=parent_server:active_nodes(),
    {ok,UpdatedStoppedParents}=parent_server:stopped_nodes(),
    {ok,[{active,UpdatedActiveParents},{stopped,UpdatedStoppedParents}]}.
%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
start_pod_nodes()->	
    {ok,StoppedPods}=pod_server:stopped_nodes(),
    [ok,ok]=[pod_server:create_node(Pod)||Pod<-StoppedPods],
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
    io:format("Ping  ~p~n",[{rpc:call(PodNode,App,ping,[],2000),PodNode,ApplSpec,?MODULE,?FUNCTION_NAME,?LINE}]),
    io:format("Creat Appl Result ~p~n",[{Result,PodNode,ApplSpec,?MODULE,?FUNCTION_NAME,?LINE}]),
    create_appl(T,[{Result,PodNode,ApplSpec,App}|Acc]).
    

