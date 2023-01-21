%%% -------------------------------------------------------------------
%%% Author  : uabjle
%%% Description : resource discovery accroding to OPT in Action 
%%% This service discovery is adapted to 
%%% Type = application 
%%% Instance ={ip_addr,{IP_addr,Port}}|{erlang_node,{ErlNode}}
%%% 
%%% Created : 10 dec 2012
%%% -------------------------------------------------------------------
-module(console_server).
 
-behaviour(gen_server).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
-define(HeartbeatTime,20*1000).
-define(ApplTimeOut,2*5000).
-define(LocalTypes,[oam,nodelog,db_etcd]).
-define(TargetTypes,[oam,nodelog,db_etcd]).
-define(ApplSpecs,["common","resource_discovery","nodelog","db_etcd","infra_service"]).

%% External exports




%% gen_server callbacks



-export([init/1, handle_call/3,handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%%-------------------------------------------------------------------
-record(state,{
	       cluster_spec,
	       connect_node,
	       pod_node
	      }).


%% ====================================================================
%% External functions
%% ====================================================================

	    
%% call


%% ====================================================================
%% Server functions
%% ====================================================================

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([]) -> 
   
    ok=lib_console:start_local(),

    io:format("Started Server ~p~n",[{?MODULE,?LINE}]), 
    
    {ok, #state{cluster_spec=undefined,
		connect_node=undefined,
		pod_node=undefined}}.   
 

%% --------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_call({new_cluster,ClusterSpec,HostSpec},_From, State) ->
    {ok,Cookie}=db_cluster_spec:read(cookie,ClusterSpec),
    erlang:set_cookie(node(),list_to_atom(Cookie)),
    
    Reply =if 
	       State#state.cluster_spec /= undefined ->
		   NewState=State,
		   {error,[already_connected,State#state.cluster_spec]};
	       true->
		   case do_new_cluster(ClusterSpec,HostSpec,10*1000) of
		       {error,Reason}->
			   NewState=State,
			   {error,Reason};
		       {ok,ConnectNode,PodNode}->
			   NewState=State#state{cluster_spec=ClusterSpec,connect_node=ConnectNode,pod_node=PodNode},
			   {ok,ConnectNode,PodNode}
		   end
	   end,		   
    {reply, Reply, NewState};

handle_call({connect,ClusterSpec},_From, State) ->
    Reply =if 
	       State#state.cluster_spec /= undefined ->
		   {error,[already_connected,State#state.cluster_spec]};
	       true->
		   case db_cluster_spec:member(ClusterSpec) of
		       false->
			   {error,[eexists,ClusterSpec]};
		       true->
						% Ensure right cookie
			   {ok,Cookie}=db_cluster_spec:read(cookie,ClusterSpec),
			   erlang:set_cookie(node(),list_to_atom(Cookie)),
						% Connect_nodes
			   {ok,_}=connect_server:create_dbase_info(ClusterSpec),
			   ConnectNodes=[maps:get(pod_node,Map)||Map<-connect_server:connect_nodes_info(ClusterSpec)],
			   AllNodes=lists:append([rpc:call(Node,erlang,nodes,[],2000)||Node<-ConnectNodes]),
			   _Ping=[{net_adm:ping(Node),Node}||Node<-AllNodes],
			
			   %io:format("Ping ~p~n",[{Ping,?MODULE,?FUNCTION_NAME}]),
			   %io:format("nodes() ~p~n",[{nodes(),?MODULE,?FUNCTION_NAME}]),
			   [rd:add_local_resource(Type,node())||Type<-?LocalTypes],
			   [rd:add_target_resource_type(Type)||Type<-?TargetTypes],
			   ok=rd:trade_resources(),
			   timer:sleep(3000),
			   ok
		   end
	   end,
    {reply, Reply, State};
 
  

handle_call({disconnect},_From, State) ->
    NewState=State#state{cluster_spec=undefined},
    Reply=ok,
    {reply, Reply, NewState};


handle_call({deploy_appls},_From, State) ->
    Reply=appl_server:deploy_appls(State#state.cluster_spec),
    {reply, Reply, State};


handle_call({new_appl,ApplSpec,HostSpec},_From, State) ->
    Reply= appl_server:new(ApplSpec,HostSpec,State#state.cluster_spec,?ApplTimeOut),
    {reply, Reply, State};


handle_call({new_appl,ApplSpec,HostSpec,TimeOut},_From, State) ->
    Reply= appl_server:new(ApplSpec,HostSpec,State#state.cluster_spec,TimeOut),
    {reply, Reply, State};

handle_call({delete_appl,AppSpec,PodNode},_From, State) ->
    Reply=appl_server:delete(AppSpec,PodNode),
  
    {reply, Reply, State};

handle_call({update_appl,AppSpec,PodNode,HostSpec},_From, State) ->
    Reply=case appl_server:delete(AppSpec,PodNode)of
	      {error,Reason}->
		  {error,Reason};
	      ok->
		  appl_server:new(AppSpec,HostSpec)
	  end,
		  
    {reply, Reply, State};

handle_call({new_db_info},_From, State) ->
    Reply=connect_server:create_dbase_info(State#state.cluster_spec),
    {reply, Reply, State};

handle_call({new_connect_nodes},_From, State) ->
    Reply=connect_server:create_connect_nodes(State#state.cluster_spec),
    {reply, Reply, State};

handle_call({new_controllers},_From, State) ->
    Reply=pod_server:create_controller_pods(State#state.cluster_spec),
    {reply, Reply, State};

handle_call({new_workers},_From, State) ->
    Reply=pod_server:create_worker_pods(State#state.cluster_spec),
    {reply, Reply, State};

handle_call({ping_connect_nodes},_From, State) ->
    ConnectNodes=db_cluster_instance:nodes(connect,State#state.cluster_spec),
    PingConnectNodes=[{net_adm:ping(Node),Node}||Node<-ConnectNodes],
    Reply={ok,PingConnectNodes},
    {reply, Reply, State};

handle_call({is_cluster_deployed},_From, State) ->
    Reply=glurk_not_implmented,
    {reply, Reply, State};

handle_call({delete_cluster},_From, State) ->
    Reply=glurk_not_implemented,
    {reply, Reply, State};


handle_call({all_apps},_From, State) ->
    ControllerNodes=pod_server:present_controller_nodes(),
    WorkerNodes=pod_server:present_worker_nodes(),
    AllNodes=lists:append(ControllerNodes,WorkerNodes),
    Apps=[{Node,rpc:call(Node,net,gethostname,[],5*1000),rpc:call(Node,application,which_applications,[],5*1000)}||Node<-AllNodes],
    AllApps=[{Node,HostName,AppList}||{Node,{ok,HostName},AppList}<-Apps,
				      AppList/={badrpc,nodedown}],
    Reply={ok,AllApps},
    {reply, Reply, State};

handle_call({where_is_app,App},_From, State) ->
    ControllerNodes=pod_server:present_controller_nodes(),
    WorkerNodes=pod_server:present_worker_nodes(),
    AllNodes=lists:append(ControllerNodes,WorkerNodes),
    Apps=[{Node,rpc:call(Node,net,gethostname,[],5*1000),rpc:call(Node,application,which_applications,[],5*1000)}||Node<-AllNodes],
    AllApps=[{Node,HostName,AppList}||{Node,{ok,HostName},AppList}<-Apps,
				      AppList/={badrpc,nodedown}],
    HereTheyAre=[Node||{Node,_HostName,AppList}<-AllApps,
		       lists:keymember(App,1,AppList)],
    Reply={ok,HereTheyAre},
    {reply, Reply, State};

handle_call({present_apps},_From, State) ->
    PresentApps=appl_server:present_apps(State#state.cluster_spec),
    Reply={ok,PresentApps},						 
    {reply, Reply, State};

handle_call({missing_apps},_From, State) ->
    MissingApps=appl_server:missing_apps(State#state.cluster_spec),
    Reply={ok,MissingApps},
    {reply, Reply, State};

handle_call({get_state},_From, State) ->
    Reply=State,
    {reply, Reply, State};


handle_call({ping},_From, State) ->
    Reply=pong,
    {reply, Reply, State};

handle_call({stop},_From, State) ->
    {stop, normal,stopped, State};

handle_call(Request, From, State) ->
    Reply = {unmatched_signal,?MODULE,Request,From},
    {reply, Reply, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_cast(Msg, State) ->
    io:format("unmatched match cast ~p~n",[{Msg,?MODULE,?LINE}]),
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_info({ssh_cm,_,_}, State) ->
    {noreply, State};

handle_info(Info, State) ->
    io:format("unmatched match~p~n",[{Info,?MODULE,?LINE}]), 
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% --------------------------------------------------------------------
%%% Internal functions
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
do_new_cluster(ClusterSpec,HostSpec,TimeOut)->
    {ok,_}=connect_server:create_dbase_info(ClusterSpec),    
    NodesToConnect=db_cluster_instance:nodes(connect,ClusterSpec),
    [ConnectPodNode]=[ConnectPodNode||ConnectPodNode<-NodesToConnect,
			{ok,HostSpec}==db_cluster_instance:read(host_spec,ClusterSpec,ConnectPodNode)],
    Result=case connect_server:create_connect_node(ClusterSpec,ConnectPodNode,[node()]) of
	       {error,Reason}->
		   {error,Reason};
	       {ok,ConnectNode,_NodeDir,_PingResult}->
		   pod_server:create_controller_pods(ClusterSpec),
		   pod_server:create_worker_pods(ClusterSpec),
		   % create pod using common as the first app to load  start
		   case pod_server:get_pod("common",HostSpec) of
		       {error,Reason}->
			   rd:rpc_call(nodelog,nodelog,log,[warning,?MODULE_STRING,?LINE,{error,Reason}]),
			   {error,Reason};
		       []->
			   rd:rpc_call(nodelog,nodelog,log,[warning,?MODULE_STRING,?LINE,{error,[no_pods_available]}]),
			   {error,[no_pods_available,?MODULE,?LINE]};
		       {ok,PodNode}->
			   % -define(ApplSpecs,["common","resource_discovery","nodelog","db_etcd","infra_service"]).
			   
			   ok=load_start_appl("common",PodNode,ClusterSpec,HostSpec,TimeOut),	  
			   ok=load_start_appl("resource_discovery",PodNode,ClusterSpec,HostSpec,TimeOut),	
			   ok=load_start_appl("db_etcd",PodNode,ClusterSpec,HostSpec,TimeOut),
			   ok=db_config:create_table(),
			   {atomic,ok}=db_config:set(cluster_spec,ClusterSpec),

			   ok=load_start_appl("nodelog",PodNode,ClusterSpec,HostSpec,TimeOut),
			   ok=load_start_appl("infra_service",PodNode,ClusterSpec,HostSpec,TimeOut),
			   ok
		   end
	   end,
    Result.
%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------

load_start_appl(ApplSpec,PodNode,ClusterSpec,HostSpec,TimeOut)->
    {ok,PodDir}=db_cluster_instance:read(pod_dir,ClusterSpec,PodNode),
    {ok,PodApplGitPath}=db_appl_spec:read(gitpath,ApplSpec),
    ApplDir=filename:join([PodDir,ApplSpec]),
		   %% set application envs
    {ok,ApplicationConfig}=db_host_spec:read(application_config,HostSpec),  
    _SetEnvResult=[rpc:call(PodNode,application,set_env,[[Config]],5000)||Config<-ApplicationConfig],
    Result=case appl_server:load_start(ApplSpec,PodNode,PodApplGitPath,ApplDir,TimeOut) of
	       {error,Reason}->
		   rd:rpc_call(nodelog,nodelog,log,[warning,?MODULE_STRING,?LINE,{error,Reason}]),
		   {error,Reason};
	       ok->
		   {atomic,ok}=db_appl_instance:create(ClusterSpec,ApplSpec,PodNode,HostSpec,{date(),time()}),
		   rd:rpc_call(nodelog,nodelog,log,[notice,?MODULE_STRING,?LINE,["application created ",ApplSpec,PodNode]]),
		   ok
	   end,
    Result.
