-module(concurix_runtime).
-export([start/2]).

start(Filename, Options) ->
  case lists:member(msg_trace, Options) of
    true  ->
      {ok, CWD }          = file:get_cwd(),
      Dirs                = code:get_path(),

      {ok, Config, _File} = file:path_consult([CWD | Dirs], Filename),

      setup_ets_tables([concurix_config_master]),
      setup_config(Config),

      application:start(crypto),
      application:start(ranch),
      application:start(cowboy),
      application:start(gproc),

      %% {Host, list({Path, Handler, Opts})}
      Dispatch = cowboy_router:compile([{'_', [{"/", concurix_trace_socket_handler, []} ]}]),

      %% Name, NbAcceptors, Transport, TransOpts, Protocol, ProtoOpts
      cowboy:start_http(http, 100, [{port, 6788}], [{env, [{dispatch, Dispatch}]}]),

      concurix_trace_client:start();

    false ->
      ok
 end.
 
%% Setup ets tables for configuration now to simplify the compile logic.
setup_ets_tables([]) ->
  ok;

setup_ets_tables([Head | Tail]) ->
  case ets:info(Head) of
    undefined ->
      ets:new(Head, [public, named_table, {read_concurrency, true}, {heir, whereis(init), concurix}]);

    _ -> 
      ets:delete_all_objects(Head)
  end,

  setup_ets_tables(Tail).
 



setup_config([]) ->
  ok;

setup_config([{master, MasterConfig} | Tail]) ->
  lists:foreach(fun(X) -> {Key, Val} = X, ets:insert(concurix_config_master, {Key, Val}) end, MasterConfig),
  setup_config(Tail);

setup_config([Head | Tail]) ->
  io:format("unknown concurix configuration ~p ~n", [Head]),
  setup_config(Tail).
