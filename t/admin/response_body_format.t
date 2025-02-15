#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
use t::APISIX 'no_plan';

repeat_each(1);
no_long_string();
no_root_location();
no_shuffle();
log_level("info");

add_block_preprocessor(sub {
    my ($block) = @_;

    my $user_yaml_config = <<_EOC_;
apisix:
    node_listen: 1984
    admin_key: null
    admin_api_version: v3
_EOC_
    $block->set_value("yaml_config", $user_yaml_config);

    if (!$block->request) {
        $block->set_value("request", "GET /t");
    }

    if (!$block->no_error_log && !$block->error_log) {
        $block->set_value("no_error_log", "[error]\n[alert]");
    }
});

run_tests;

__DATA__

=== TEST 1: use v3 admin api, no action in response body
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test

            local code, body = t('/apisix/admin/routes/1',
                ngx.HTTP_PUT,
                [[{
                    "methods": ["GET"],
                    "upstream": {
                        "nodes": {
                            "127.0.0.1:8080": 1
                        },
                        "type": "roundrobin"
                    },
                    "desc": "new route",
                    "uri": "/index.html"
                }]],
                [[{
                    "node": {
                        "value": {
                            "methods": [
                                "GET"
                            ],
                            "uri": "/index.html",
                            "desc": "new route",
                            "upstream": {
                                "nodes": {
                                    "127.0.0.1:8080": 1
                                },
                                "type": "roundrobin"
                            }
                        },
                        "key": "/apisix/routes/1"
                    }
                }]]
                )

            ngx.status = code
            ngx.say(body)
        }
    }
--- response_body
passed



=== TEST 2: response body format only have count and list(count is 1)
--- config
    location /t {
        content_by_lua_block {
            local json = require("toolkit.json")
            local t = require("lib.test_admin").test
            local code, message, res = t('/apisix/admin/routes',
                ngx.HTTP_GET
            )

            if code >= 300 then
                ngx.status = code
                ngx.say(message)
                return
            end

            res = json.decode(res)
            assert(res.count == #res.list)
            assert(res.action == nil)
            assert(res.node == nil)
            assert(res.list.key == nil)
            assert(res.list.dir == nil)
            ngx.say(json.encode(res))
        }
    }
--- response_body eval
qr/\{"count":1,"list":\[\{.*\}\]/



=== TEST 3: response body format only have count and list(count is 2)
--- config
    location /t {
        content_by_lua_block {
            local json = require("toolkit.json")
            local t = require("lib.test_admin").test
            local code, body = t('/apisix/admin/routes/2',
                ngx.HTTP_PUT,
                [[{
                    "methods": ["GET"],
                    "upstream": {
                        "nodes": {
                            "127.0.0.1:8080": 1
                        },
                        "type": "roundrobin"
                    },
                    "desc": "new route",
                    "uri": "/index.html"
                }]]
            )

            if code >= 300 then
                ngx.status = code
                ngx.say(body)
            end

            local code, message, res = t('/apisix/admin/routes',
                ngx.HTTP_GET
            )

            if code >= 300 then
                ngx.status = code
                ngx.say(message)
                return
            end

            res = json.decode(res)
            assert(res.count == #res.list)
            assert(res.action == nil)
            assert(res.node == nil)
            assert(res.list.key == nil)
            assert(res.list.dir == nil)
            ngx.say(json.encode(res))
        }
    }
--- response_body eval
qr/\{"count":2,"list":\[\{.*\},\{.*\}\]/



=== TEST 4: response body format(test services)
--- config
    location /t {
        content_by_lua_block {
            local json = require("toolkit.json")
            local t = require("lib.test_admin").test
            local code, body = t('/apisix/admin/services/1',
                 ngx.HTTP_PUT,
                 [[{
                    "upstream": {
                        "nodes": {
                            "127.0.0.1:1980": 1
                        },
                        "type": "roundrobin"
                    },
                    "desc": "new service 001"
                }]]
                )
            if code >= 300 then
                ngx.status = code
            end
            ngx.say(body)

            local code, body = t('/apisix/admin/services/2',
                 ngx.HTTP_PUT,
                 [[{
                    "upstream": {
                        "nodes": {
                            "127.0.0.1:1980": 1
                        },
                        "type": "roundrobin"
                    },
                    "desc": "new service 002"
                }]]
                )
            if code >= 300 then
                ngx.status = code
            end
            ngx.say(body)

            local code, message, res = t('/apisix/admin/services',
                ngx.HTTP_GET
            )

            if code >= 300 then
                ngx.status = code
                ngx.say(message)
                return
            end

            res = json.decode(res)
            assert(res.count == #res.list)
            assert(res.action == nil)
            assert(res.node == nil)
            assert(res.list.key == nil)
            assert(res.list.dir == nil)
            ngx.say(json.encode(res))
        }
    }
--- response_body eval
qr/\{"count":2,"list":\[\{.*\},\{.*\}\]/
