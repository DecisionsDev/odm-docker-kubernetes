ARG KEYCLOAK_IMAGE
FROM ${KEYCLOAK_IMAGE} as builder

# Enable health and metrics support
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

# Configure a database vendor
ENV KC_DB=postgres

WORKDIR /opt/keycloak
ARG SCIM_JAR_FILE
COPY ./${SCIM_JAR_FILE} /opt/keycloak/providers/${SCIM_JAR_FILE}

RUN /opt/keycloak/bin/kc.sh build

FROM ${KEYCLOAK_IMAGE}
COPY --from=builder /opt/keycloak/ /opt/keycloak/

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
