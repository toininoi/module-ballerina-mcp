// Copyright (c) 2026 WSO2 LLC (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/mcp;
import ballerina/test;

// An advanced Streamable HTTP service: onCallTool additionally receives the underlying http:Request.
@mcp:StreamableHttpServiceConfig {
    info: {name: "advanced-http-server", version: "1.0.0"},
    sessionMode: mcp:STATELESS
}
isolated service mcp:StreamableHttpAdvancedService /mcp on new mcp:StreamableHttpListener(8771) {

    isolated remote function onListTools() returns mcp:ListToolsResult|mcp:ServerError {
        return {
            tools: [
                {name: "whoAmI", description: "Returns the Authorization header", inputSchema: {'type: "object"}}
            ]
        };
    }

    isolated remote function onCallTool(mcp:CallToolParams params, mcp:Session? session, http:Request request)
            returns mcp:CallToolResult|mcp:ServerError {
        string|http:HeaderNotFoundError auth = request.getHeader("Authorization");
        return {content: [{'type: "text", text: auth is string ? auth : "<none>"}]};
    }
}

final http:Client rawAdvancedClient = check new ("http://localhost:8771");

@test:Config
function testStreamableHttpAdvancedServiceListTools() returns error? {
    http:Request request = new;
    request.setJsonPayload({jsonrpc: "2.0", id: 1, method: "tools/list", params: {}});
    request.setHeader("Accept", "application/json, text/event-stream");
    http:Response response = check rawAdvancedClient->post("/mcp", request);
    json result = check response.getJsonPayload();
    json[] tools = check (check result.result.tools).ensureType();
    test:assertEquals(tools.length(), 1);
    test:assertEquals(check tools[0].name, "whoAmI");
}

@test:Config
function testStreamableHttpAdvancedServiceHeaderAccess() returns error? {
    http:Request request = new;
    request.setJsonPayload({jsonrpc: "2.0", id: 2, method: "tools/call",
        params: {name: "whoAmI", arguments: {}}});
    request.setHeader("Accept", "application/json, text/event-stream");
    request.setHeader("Authorization", "Bearer adv-token");
    http:Response response = check rawAdvancedClient->post("/mcp", request);
    json result = check response.getJsonPayload();
    test:assertEquals(check getRawTextResult(result), "Bearer adv-token");
}
