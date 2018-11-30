%% Copyright (c) 2018 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(emqx_auth_ldap).

-include_lib("emqx/include/emqx.hrl").
-include_lib("eldap/include/eldap.hrl").

-import(emqx_auth_ldap_cli, [search/2, fill/2, gen_filter/2]).

-export([init/1, check/3, description/0]).

-define(EMPTY(Username), (Username =:= undefined orelse Username =:= <<>>)).

init({AuthDn, HashType}) ->
    {ok, #{auth_dn => AuthDn, hash_type => HashType}}.

check(#{username := Username}, Password, _State) when ?EMPTY(Username); ?EMPTY(Password) ->
    {error, username_or_password_undefined};

check(Credentials, Password, #{auth_dn := AuthDn, hash_type := HashType}) ->
    Filter = gen_filter(Credentials, AuthDn),
    case search(fill(Credentials, AuthDn), Filter) of
        {ok, #eldap_search_result{entries = []}} ->
            ignore;
        {ok, #eldap_search_result{entries = [Entry]}} ->
            Attributes = Entry#eldap_entry.attributes,
            emqx_passwd:check_pass({list_to_binary(proplists:get_value("password", Attributes)), Password}, HashType);
        {error, Reason} ->
            {error, Reason}
    end.

description() -> "LDAP Authentication Plugin".

