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

%% External exports




%% gen_server callbacks



-export([init/1, handle_call/3,handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%%-------------------------------------------------------------------
-record(state,{
	       cluster_spec,
	       pods
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
   
    io:format("Started Server ~p~n",[{?MODULE,?LINE}]), 
    
    {ok, #state{cluster_spec=undefined,
		pods=undefined}}.   
 

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
handle_call({new_cluster,ClusterSpec},_From, State) ->
    Reply=case State#state.cluster_spec of
	      undefined ->
		  case lib_console:new_cluster(ClusterSpec) of
		      {error,Reason}->
			  NewState=State,
			  {error,Reason};
		      ok->
			  NewState=State#state{cluster_spec=ClusterSpec},
			  ok
		  end;
	      _ ->
		  NewState=State,
		  {error,["Already created : ",State#state.cluster_spec]}
	  end,		   
    {reply, Reply, NewState};

handle_call({connect,ClusterSpec},_From, State) ->
    Reply =case State#state.cluster_spec of
	       undefined->
		   ok=local:start_local(ClusterSpec),
		   ok=parent_server:load_desired_state(ClusterSpec),
		   ok=pod_server:load_desired_state(ClusterSpec),
		   ok=appl_server:load_desired_state(ClusterSpec),
		   [DbEtcd]=sd:get_node(db_etcd),
		   Pods=rpc:call(DbEtcd,db_pod_desired_state,get_all_id,[],10*1000),
		   application:stop(db_etcd),
		   application:stop(infra_service),
		   PingR=[{net_adm:ping(Pod),Pod}||Pod<-Pods],
		   NewState=State#state{cluster_spec=ClusterSpec,
					pods=Pods},
		   {ok,PingR};
		  
	       _->
		   NewState=State,
		   {error,[already_connected,State#state.cluster_spec]}
	   end,
    {reply, Reply, NewState};
 
  

handle_call({disconnect},_From, State) ->
    NewState=State#state{cluster_spec=undefined},
    Reply=ok,
    {reply, Reply, NewState};


handle_call({deploy_appls},_From, State) ->
    Reply=appl_server:deploy_appls(State#state.cluster_spec),
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


