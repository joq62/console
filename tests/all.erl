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
    
 
-export([start/1]).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------
start([ClusterSpec])->
    io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME}]),
    
    ok=setup(ClusterSpec),
        
    io:format("Stop OK !!! ~p~n",[{?MODULE,?FUNCTION_NAME}]),
 %   timer:sleep(2000),
 %  init:stop(),
    ok.


%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------

setup()->
    io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME}]),
  
    ok.


%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------

setup(ClusterSpec)->
    io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME}]),

    ok=application:start(common),
    pong=common:ping(),
    io:format("Start  ~p~n",[{common,?MODULE,?FUNCTION_NAME}]),
    ok=application:start(resource_discovery),
    pong=rd:ping(),
    io:format("Start  ~p~n",[{resource_discovery,?MODULE,?FUNCTION_NAME}]),
    ok=application:start(nodelog),
    pong=nodelog:ping(),
   io:format("Start  ~p~n",[{nodelog,?MODULE,?FUNCTION_NAME}]),
    ok=application:start(db_etcd),
    pong=db_etcd:ping(),
    ok=db_config:create_table(),
    {atomic,ok}=db_config:set(cluster_spec,ClusterSpec),
    ClusterSpec=db_config:get(cluster_spec),
    io:format("Start  ~p~n",[{db_etcd,?MODULE,?FUNCTION_NAME}]),   
    ok=application:start(console),
    pong=console:ping(),
    io:format("Start  ~p~n",[{console,?MODULE,?FUNCTION_NAME}]),
    
    ok.
