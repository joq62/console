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
-module(a).      
    
-export([
	 running_nodes/1,
	 notice/0,warning/0,alert/0,
	 stop/0,stop/1,
	 all_apps/0
	]).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
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
stop()->
    stop(c200_c201_parent@c201).

stop(N)->
    rpc:call(N,init,stop,[],5000).

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

