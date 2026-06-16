/*
 * Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
 *
 * WSO2 LLC. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.ballerina.stdlib.mcp.plugin;

import io.ballerina.projects.DiagnosticResult;
import io.ballerina.projects.Package;
import io.ballerina.projects.ProjectEnvironmentBuilder;
import io.ballerina.projects.directory.BuildProject;
import io.ballerina.projects.environment.Environment;
import io.ballerina.projects.environment.EnvironmentBuilder;
import io.ballerina.tools.diagnostics.Diagnostic;
import io.ballerina.tools.diagnostics.DiagnosticSeverity;
import org.testng.Assert;
import org.testng.annotations.Test;

import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Tests for the MCP compiler plugin diagnostics on '@http:Header' and 'http:Headers' tool parameters.
 */
public class CompilerPluginTest {

    private static final Path RESOURCE_DIRECTORY = Paths.get("src", "test", "resources", "ballerina_sources")
            .toAbsolutePath();
    private static final Path DISTRIBUTION_PATH = Paths.get("../", "target", "ballerina-runtime")
            .toAbsolutePath();

    private static final String MCP_104 = "MCP_104";
    private static final String MCP_105 = "MCP_105";
    private static final String MCP_106 = "MCP_106";
    private static final String MCP_107 = "MCP_107";

    private Package loadPackage(String path) {
        Path projectDirPath = RESOURCE_DIRECTORY.resolve(path);
        BuildProject project = BuildProject.load(getEnvironmentBuilder(), projectDirPath);
        return project.currentPackage();
    }

    private static ProjectEnvironmentBuilder getEnvironmentBuilder() {
        Environment environment = EnvironmentBuilder.getBuilder().setBallerinaHome(DISTRIBUTION_PATH).build();
        return ProjectEnvironmentBuilder.getBuilder(environment);
    }

    private DiagnosticResult compile(String path) {
        Package currentPackage = loadPackage(path);
        // The MCP compiler plugin is registered as a CodeModifier, so its diagnostics are
        // reported by the code-generate/modify phase, not by getCompilation() alone
        return currentPackage.runCodeGenAndModifyPlugins();
    }

    private long errorCount(DiagnosticResult diagnosticResult) {
        return diagnosticResult.diagnostics().stream()
                .filter(d -> d.diagnosticInfo().severity().equals(DiagnosticSeverity.ERROR)).count();
    }

    private void assertError(DiagnosticResult diagnosticResult, int index, String messagePart, String code) {
        Diagnostic diagnostic = (Diagnostic) diagnosticResult.errors().toArray()[index];
        Assert.assertTrue(diagnostic.message().contains(messagePart),
                "expected message containing '" + messagePart + "' but found: " + diagnostic.message());
        Assert.assertEquals(diagnostic.diagnosticInfo().code(), code);
    }

    @Test
    public void testValidHeaderParameterTypes() {
        DiagnosticResult diagnosticResult = compile("sample_package_1");
        Assert.assertEquals(errorCount(diagnosticResult), 0,
                "valid header parameter shapes must not produce errors: "
                        + diagnosticResult.errors().toString());
    }

    @Test
    public void testInvalidUnionHeaderParamType() {
        DiagnosticResult diagnosticResult = compile("sample_package_2");
        Assert.assertEquals(errorCount(diagnosticResult), 1);
        assertError(diagnosticResult, 0, "Invalid type of header param 'mixed'", MCP_106);
    }

    @Test
    public void testHeaderRecordWithRestFields() {
        DiagnosticResult diagnosticResult = compile("sample_package_3");
        Assert.assertEquals(errorCount(diagnosticResult), 1);
        assertError(diagnosticResult, 0, "Invalid type of header param 'hdrs'", MCP_106);
    }

    @Test
    public void testDuplicateHttpHeadersParams() {
        DiagnosticResult diagnosticResult = compile("sample_package_4");
        Assert.assertEquals(errorCount(diagnosticResult), 1);
        assertError(diagnosticResult, 0, "Duplicate parameter 'second'", MCP_105);
        assertError(diagnosticResult, 0, "type 'http:Headers'", MCP_105);
    }

    @Test
    public void testInvalidHeaderParamType() {
        DiagnosticResult diagnosticResult = compile("sample_package_5");
        Assert.assertEquals(errorCount(diagnosticResult), 1);
        assertError(diagnosticResult, 0, "Invalid type of header param 'payload'", MCP_106);
    }

    @Test
    public void testHeaderParamRequiresStreamableHttpService() {
        DiagnosticResult diagnosticResult = compile("sample_package_6");
        Assert.assertEquals(errorCount(diagnosticResult), 1);
        assertError(diagnosticResult, 0, "accesses transport-specific properties", MCP_107);
    }

    @Test
    public void testSessionParamStatelessViaTransportConfig() {
        DiagnosticResult diagnosticResult = compile("sample_package_7");
        Assert.assertEquals(errorCount(diagnosticResult), 1);
        assertError(diagnosticResult, 0, "is not allowed when sessionMode is STATELESS", MCP_104);
    }

    @Test
    public void testRawHeadersParamRequiresStreamableHttpService() {
        DiagnosticResult diagnosticResult = compile("sample_package_8");
        Assert.assertEquals(errorCount(diagnosticResult), 1);
        assertError(diagnosticResult, 0, "accesses transport-specific properties", MCP_107);
    }

    @Test
    public void testRequestParamRequiresStreamableHttpService() {
        DiagnosticResult diagnosticResult = compile("sample_package_9");
        Assert.assertEquals(errorCount(diagnosticResult), 1);
        assertError(diagnosticResult, 0, "accesses transport-specific properties", MCP_107);
    }

    @Test
    public void testDuplicateHttpRequestParams() {
        DiagnosticResult diagnosticResult = compile("sample_package_10");
        Assert.assertEquals(errorCount(diagnosticResult), 1);
        assertError(diagnosticResult, 0, "Duplicate parameter 'second'", MCP_105);
        assertError(diagnosticResult, 0, "type 'http:Request'", MCP_105);
    }
}
