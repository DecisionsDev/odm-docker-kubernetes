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
				// TODO Auto-generated catch block
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
				// TODO Auto-generated catch block
				e.printStackTrace();
			} catch (InterruptedException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}

		} finally {
			client.close();
		}
	}

}
