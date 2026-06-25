// Copyright (c) 2025 WSO2 LLC (http://www.wso2.com).
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

# Retrieves the service configuration from an MCP service.
#
# + mcpService - The MCP service instance
# + return - The service configuration
isolated function getServiceConfiguration(Service|AdvancedService mcpService) returns ServiceConfiguration {
    typedesc mcpServiceType = typeof mcpService;
    ServiceConfiguration? serviceConfig = mcpServiceType.@ServiceConfig;
    return serviceConfig ?: {
        info: {
            name: "MCP Service",
            version: "1.0.0"
        }
    };
}

# Extracts session ID from HTTP headers.
#
# + headers - HTTP headers to extract session ID from
# + return - Session ID if present, otherwise nil
isolated function getSessionIdFromHeaders(http:Headers headers) returns string? {
    string|http:HeaderNotFoundError sessionHeader = headers.getHeader(SESSION_ID_HEADER);
    return sessionHeader is string ? sessionHeader : ();
}

# Determines the effective session mode based on configuration and request context.
#
# + config - Service configuration
# + headers - HTTP request headers
# + requestMethod - The MCP request method (optional, used for AUTO mode logic)
# + return - Effective session mode to use
isolated function determineEffectiveSessionMode(ServiceConfiguration config, http:Headers headers, RequestMethod? requestMethod = ()) returns SessionMode {
    SessionMode configuredMode = config.sessionMode;

    if configuredMode == STATEFUL || configuredMode == STATELESS {
        return configuredMode;
    }

    // AUTO mode logic
    if requestMethod == REQUEST_INITIALIZE {
        // For initialize requests in AUTO mode, always treat as STATEFUL
        // since initialize is where we create sessions
        return STATEFUL;
    }

    // For non-initialize requests in AUTO mode, determine based on session header presence
    string? sessionId = getSessionIdFromHeaders(headers);
    return sessionId is string ? STATEFUL : STATELESS;
}

# Creates a standard JSON-RPC error response.
#
# + code - Error code
# + message - Error message
# + id - Request ID (optional)
# + return - JSON-RPC error response
isolated function createJsonRpcError(int code, string message, RequestId? id = ()) returns JsonRpcError & readonly => {
    jsonrpc: JSONRPC_VERSION,
    id: id,
    'error: {
        code: code,
        message: message
    }
};

# Validates that required HTTP headers are present and valid.
#
# + headers - HTTP headers to validate
# + return - Error response if validation fails, otherwise nil
isolated function validateRequiredHeaders(http:Headers headers) returns http:NotAcceptable|http:UnsupportedMediaType? {
    string|http:HeaderNotFoundError acceptHeader = headers.getHeader(ACCEPT_HEADER);
    if acceptHeader is http:HeaderNotFoundError {
        return <http:NotAcceptable>{
            body: createJsonRpcError(NOT_ACCEPTABLE,
                    "Not Acceptable: Client must accept both application/json and text/event-stream")
        };
    }

    if !acceptHeader.includes(CONTENT_TYPE_JSON) || !acceptHeader.includes(CONTENT_TYPE_SSE) {
        return <http:NotAcceptable>{
            body: createJsonRpcError(NOT_ACCEPTABLE,
                    "Not Acceptable: Client must accept both application/json and text/event-stream")
        };
    }

    string|http:HeaderNotFoundError contentTypeHeader = headers.getHeader(CONTENT_TYPE_HEADER);
    if contentTypeHeader is http:HeaderNotFoundError {
        return <http:UnsupportedMediaType>{
            body: createJsonRpcError(UNSUPPORTED_MEDIA_TYPE,
                    "Unsupported Media Type: Content-Type must be application/json")
        };
    }

    if !contentTypeHeader.includes(CONTENT_TYPE_JSON) {
        return <http:UnsupportedMediaType>{
            body: createJsonRpcError(UNSUPPORTED_MEDIA_TYPE,
                    "Unsupported Media Type: Content-Type must be application/json")
        };
    }

    return;
}

# Selects the protocol version to negotiate based on the client's requested version.
# Echoes the requested version if supported; otherwise falls back to the latest supported version,
# as required by the MCP version-negotiation lifecycle.
#
# + requestedVersion - The protocol version requested by the client
# + return - The negotiated protocol version
isolated function selectProtocolVersion(string requestedVersion) returns string {
    foreach string supportedVersion in SUPPORTED_PROTOCOL_VERSIONS {
        if supportedVersion == requestedVersion {
            return requestedVersion;
        }
    }
    return LATEST_PROTOCOL_VERSION;
}

# Extracts the `MCP-Protocol-Version` header value from the request headers, if present.
#
# + headers - HTTP headers to inspect
# + return - The protocol version header value, or nil if absent
isolated function getProtocolVersionFromHeaders(http:Headers headers) returns string? {
    string|http:HeaderNotFoundError versionHeader = headers.getHeader(PROTOCOL_VERSION_HEADER);
    return versionHeader is string ? versionHeader : ();
}

# Validates the `MCP-Protocol-Version` header sent on requests after initialization.
# Per the Streamable HTTP transport spec: an absent header is tolerated (the server assumes
# `2025-03-26` for backward compatibility), while a present but unsupported value must be rejected
# with HTTP 400 Bad Request.
#
# + protocolVersion - The protocol version header value, or nil if absent
# + return - A `400 Bad Request` response if the header is present and unsupported, otherwise nil
isolated function validateProtocolVersionHeader(string? protocolVersion) returns http:BadRequest? {
    if protocolVersion is () {
        return;
    }
    foreach string supportedVersion in SUPPORTED_PROTOCOL_VERSIONS {
        if supportedVersion == protocolVersion {
            return;
        }
    }
    return <http:BadRequest>{
        body: createJsonRpcError(INVALID_REQUEST,
                string `Unsupported MCP-Protocol-Version header: ${protocolVersion}`)
    };
}
