# Copyright contributors to the IBM ODM MCP Server project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import java.io.IOException;
import java.time.Duration;
import java.net.HttpURLConnection;
import java.net.URI;

import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;

public class DecisionServiceExecution {

	public static void main(String[] args) {

		String endpointURI = "https://<DECISION_SERVER_RUNTIME_ROUTE>/DecisionService/rest/v1/production_deployment/1.0/loan_validation_production/1.0";

		Path payloadFilePath = Path.of("./payload.json");

		System.setProperty("javax.net.ssl.trustStore", "./server-truststore.p12");
		System.setProperty("javax.net.ssl.trustStorePassword", "<TRUSTSTORE-PASSWORD>");
		System.setProperty("javax.net.ssl.trustStoreType", "PKCS12");

		System.setProperty("javax.net.debug","ssl:handshake");

		System.setProperty("javax.net.ssl.keyStore", "./client-keystore.p12");
		System.setProperty("javax.net.ssl.keyStorePassword", "<KEYSTORE-PASSWORD>");
		System.setProperty("javax.net.ssl.keyStoreType", "PKCS12");


		// Create client
		HttpClient client = HttpClient.newBuilder()
				.version(HttpClient.Version.HTTP_2)
				.connectTimeout(Duration.ofSeconds(10))
				.build();

		try {

			// POST request with JSON
			HttpRequest postRequest = null;
			try {
				postRequest = HttpRequest.newBuilder()
						.uri(URI.create(endpointURI))
						.header("Content-Type", "application/json")
						.header("Authorization", "Basic b2RtQWRtaW46b2RtQWRtaW4=")  // Can be commented if executed without authorization
						.POST(HttpRequest.BodyPublishers.ofString(Files.readString(payloadFilePath)))
						.build();
			} catch (IOException e) {
				e.printStackTrace();
			}

			// Send request and get response
			HttpResponse<String> postResponse;
			try {
				postResponse = client.send(postRequest, HttpResponse.BodyHandlers.ofString());
				if (postResponse.statusCode() != HttpURLConnection.HTTP_OK) {
					System.err.println("Error with status Code: " + postResponse.statusCode());
				} else {
					System.out.println(postResponse.body());
				}
			} catch (IOException e) {
				e.printStackTrace();
			} catch (InterruptedException e) {
				e.printStackTrace();
			}

		} finally {
			client.close();
		}
	}

}
