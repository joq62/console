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
-module(console_start).      
 
-export([start/0]).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-define(ClusterSpec,"c200").

%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------
start()->
    io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME}]),

    ok=setup(),
    ok=connect(),
  %  ok=hw_conbee_app_test(),
    % ok=deploy_appls_test(),
    

  
  
    io:format("Stop OK !!! ~p~n",[{?MODULE,?FUNCTION_NAME}]),

    ok.

%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------
connect()->
    io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME}]),
    
    ok=console:connect(?ClusterSpec),
    
    ok.
    
    
    


%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------

setup()->
    io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME}]),
    
    ok=application:set_env([{console,[{cluster_spec,?ClusterSpec}]}]),
    ok=application:set_env([{infra_service_app,[{cluster_spec,?ClusterSpec}]}]),
    ok=application:start(console),
    ok.
