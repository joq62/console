%%% -------------------------------------------------------------------
%%% @author  : Joq Erlang
%%% @doc: : 
%%% Created :
%%% Node end point  
%%% Creates and deletes Pods
%%% 
%%% API-kube: Interface 
%%% Pod consits beams from all services, app and app and sup erl.
%%% The setup of envs is
%%% -------------------------------------------------------------------
-module(all).      
    
 
-export([start/1,
	 notice/0,warning/0,alert/0,
	 stop/0,stop/1,
	 all_apps/0,
	 
	 print/2]).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------
-define(TestCluster,"c200_c201").

start([ClusterSpec,_HostSpec])->
    io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME}]),
    
    ok=setup(ClusterSpec),
    ok=console:new_cluster(?TestCluster),
    loop(),
       
    io:format("Stop OK !!! ~p~n",[{?MODULE,?FUNCTION_NAME}]),
 %   timer:sleep(2000),
 %  init:stop(),
    ok.



%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
-define(Sleep,30*1000).
loop()->
    timer:sleep(?Sleep),
     io:format("------------------- ~p~n",[time()]),  
    StoppedParents=sd:call(infra_service,parent_server,stopped_nodes,[],6000),
    StoppedPods=sd:call(infra_service,pod_server,stopped_nodes,[],5*5000),
    StoppedAppls=sd:call(infra_service,appl_server,stopped_appls,[],5*5000),
    io:format("StoppedParents ~p~n",[{StoppedParents,?MODULE,?FUNCTION_NAME,?LINE}]),    
    io:format("StoppedPods ~p~n",[{StoppedPods,?MODULE,?FUNCTION_NAME,?LINE}]),    
    io:format("StoppedAppls ~p~n",[{StoppedAppls,?MODULE,?FUNCTION_NAME,?LINE}]),   
    loop().


%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------

stop()->
    stop(c200_c201_parent@c201).

stop(N)->
    rpc:call(N,init,stop,[],5000).

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------


all_apps()->
    [InfraPod|_]=sd:get_node(infra_service),
    running_apps(InfraPod).

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
notice()->
    sd:call(nodelog,nodelog,read,[notice],2000).
warning()->
    sd:call(nodelog,nodelog,read,[warning],2000).
alert()->
    sd:call(nodelog,nodelog,read,[alert],2000).
    
%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
print(Arg1,Arg2)->
    io:format(Arg1,Arg2).

%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% -------------------------------------------------------------------
running_apps(Node)->
    Nodes=lists:delete(node(),[Node|rpc:call(Node,erlang,nodes,[],5000)]),
    [{N,rpc:call(N,application,which_applications,[],5000)}||N<-Nodes].

running_nodes(Node)->
    
    lists:delete(node(),[Node|rpc:call(Node,erlang,nodes,[],5000)]).

%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------

setup(_ClusterSpec)->
    io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME}]),

    ok=application:start(console),
    pong=console:ping(),
    
    
    
    ok.
