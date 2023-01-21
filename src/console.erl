%%% -------------------------------------------------------------------
%%% Author  : uabjle
%%% Description : resource discovery accroding to OPT in Action 
%%% This service discovery is adapted to 
%%% Type = application 
%%% Instance ={ip_addr,{IP_addr,Port}}|{erlang_node,{ErlNode}}
%%% 
%%% Created : 10 dec 2012
%%% -------------------------------------------------------------------
-module(console).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------

-define(SERVER,console_server).

-export([
	 new_cluster/2,
	 connect/1,

	 ping/0,
	 get_state/0
	]).

%debug
-export([
	 all_apps/0,
	 present_apps/0,
	 missing_apps/0,
	 call/5,
	 where_is_app/1
	]).

%% ====================================================================
%% External functions
%% ====================================================================

-export([
	 start/0,
	 stop/0
	]).

start()-> gen_server:start_link({local, ?SERVER}, ?SERVER, [], []).
stop()-> gen_server:call(?SERVER, {stop},infinity).


	    
%% call
new_cluster(ClusterSpec,HostSpec)->
    gen_server:call(?SERVER, {new_cluster,ClusterSpec,HostSpec},infinity).
connect(ClusterSpec)->
    gen_server:call(?SERVER, {connect,ClusterSpec},infinity).

%% debug

all_apps()->
    gen_server:call(?SERVER, {all_apps},infinity).

present_apps() ->
    gen_server:call(?SERVER, {present_apps}).

missing_apps() ->
    gen_server:call(?SERVER, {missing_apps}).

where_is_app(App)->
    gen_server:call(?SERVER, {where_is_app,App},infinity).
call(PodNode,M,F,A,T)->
    gen_server:call(?SERVER, {call,PodNode,M,F,A,T},infinity).

ping() ->
    gen_server:call(?SERVER, {ping}).

get_state() ->
    gen_server:call(?SERVER, {get_state}).
%% cast


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
