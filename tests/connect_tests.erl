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
-module(connect_tests).      
    
 
-export([start/1]).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------
start([ClusterSpec,_Arg2])->
    io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME}]),
    
    ok=setup(ClusterSpec),
    ok=init(ClusterSpec),
        
    io:format("Stop OK !!! ~p~n",[{?MODULE,?FUNCTION_NAME}]),
 %   timer:sleep(2000),
 %  init:stop(),
    ok.


%% --------------------------------------------------------------------
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------
-define(Hosts,["c200","c201"]).

init(ClusterSpec)->
    io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME}]),
    
    Cookie=list_to_atom("cookie_"++ClusterSpec),
    erlang:set_cookie(node(),Cookie),
    Parents=[list_to_atom(ClusterSpec++"_parent@"++HostName)||HostName<-?Hosts],
    AvailableParents=[Parent||Parent<-Parents,
			      pong==net_adm:ping(Parent)],
%    io:format("AvailableParents ~p~n",[{AvailableParents,?MODULE,?FUNCTION_NAME}]),
    Parents=lists:delete(node(),AvailableParents),
    [Parent|_]=Parents,
    NodesNotWorkers=[node()|Parents],
    
    Nodes=rpc:call(Parent,erlang,nodes,[],5000),
 %   io:format("Nodes ~p~n",[{Nodes,?MODULE,?FUNCTION_NAME}]),
    Workers=[Node||Node<-Nodes,
		   false==lists:member(Node,NodesNotWorkers)],
  %  io:format("Workers ~p~n",[{Workers,?MODULE,?FUNCTION_NAME}]),
    [Worker|_]=Workers,               
   % io:format("Worker ~p~n",[{Worker,?MODULE,?FUNCTION_NAME}]),
    application:stop(db_etcd),
    R1=rpc:call(Worker,application,which_applications,[],5000),
  %  io:format("R1 ~p~n",[{R1,?MODULE,?FUNCTION_NAME}]),
    pong=rpc:call(Worker,sd,call,[db_etcd,db_etcd,ping,[],5000],6000),
    glurk=rpc:call(Worker,sd,get_node,[db_etcd],6000),

    ok.
%% Function: available_hosts()
%% Description: Based on hosts.config file checks which hosts are avaible
%% Returns: List({HostId,Ip,SshPort,Uid,Pwd}
%% --------------------------------------------------------------------


setup(_ClusterSpec)->
    io:format("Start ~p~n",[{?MODULE,?FUNCTION_NAME}]),
   
    application:start(console),
    pong=console:ping(),
   
    ok.
