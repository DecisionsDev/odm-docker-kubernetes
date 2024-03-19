#!/bin/sh

configure_decisions() {
  echo "Configuring ODM Product"
  echo "Targeted Environment : $TARGETENV"

  case "$CONTAINER_NAME" in
  *) configure_decisions_odm_pod;;
  esac

}


configure_decisions_odm_pod() {
  echo "Configuring ODM Pod"
  CONTAINERENVFILE=/ibm/icp4ba/decisions/init/container.env

  echo "Extract DB information from Vault and put information in /script/init/container.env file"
  echo DB_USER=$(cat /mnt/secrets-store/db-user) >> $CONTAINERENVFILE
  echo DB_PASSWORD=$(cat /mnt/secrets-store/db-password) >> $CONTAINERENVFILE

  # echo "Inject datasource and driver files"
  # cp /ibm/icp4ba/initconfig/datasource.xml /ibm/icp4ba/decisions/customdatasource/
  # cp /ibm/icp4ba/initconfig/postgresql-42.2.18.jar /ibm/icp4ba/decisions/jdbcdrivers/

  echo "Inject Private certificate"
  # Get tls.crt and tls.key from Vault and copy it to the directory /ibm/icp4ba/shared/privatecertificates
  # Needed for Client Certificate
  #  cp /mnt/secrets-store/tls.crt /ibm/icp4ba/shared/privatecertificates/tls.crt
  #  cp /mnt/secrets-store/tls.key /ibm/icp4ba/shared/privatecertificates/tls.key

  echo "Inject trusted certificate list"
  # Get *.crt trusted certificates from Vault and copy it to the directory /ibm/icp4ba/trusted-cert-volume/
  # For ODM needs to create a sub directory that contains the crt file.
  cp /mnt/secrets-store/digicert.crt /ibm/icp4ba/shared/trustedcertificates/
  cp /mnt/secrets-store/microsoft.crt /ibm/icp4ba/shared/trustedcertificates/

  echo "Inject Kafka/BAI configuration file"
  # The sensitive information from this properties files should be retrieved from Vault
  # and replace it. This format is documented in the ODM on K8S documentations. NEeds to restore the documentation for ODM on CP4BA
  # Once the file has been generated needs to copy it to the location /ibm/icp4ba/decisions/baiemitter/
  #  cp /ibm/icp4ba/initconfig/plugin-configuration.properties  /ibm/icp4ba/decisions/baiemitter/plugin-configuration.properties

  echo "Change auth and copy files"
  # To test usecase user access without openid needs to put oidc.enabled -> false
  if [ -f /mnt/secrets-store/OdmOidcProvidersAzureAD.json ]; then echo "Updating OdmOidcProvidersAzureAD.json" && cp /mnt/secrets-store/OdmOidcProvidersAzureAD.json /ibm/icp4ba/decisions/auth/; fi;
  if [ -f /mnt/secrets-store/openIdParameters.properties ]; then echo "Updating openIdParameters.properties" && cp /mnt/secrets-store/openIdParameters.properties /ibm/icp4ba/decisions/auth/; fi;
  if [ -f /mnt/secrets-store/openIdWebSecurity.xml ]; then echo "Updating openIdWebSecurity.xml" && cp /mnt/secrets-store/openIdWebSecurity.xml /ibm/icp4ba/decisions/auth/; fi;
  if [ -f /mnt/secrets-store/webSecurity.xml ]; then echo "Updating owebSecurity.xml" && cp /mnt/secrets-store/webSecurity.xml /ibm/icp4ba/decisions/auth/; fi;
  # cp /ibm/icp4ba/initconfig/simpleWebSecurity.xml /ibm/icp4ba/decisions/auth/webSecurity.xml
}


echo "Starting configuration"
case "$PRODUCT_NAME" in
"decisions") configure_decisions;;
"operator") configure_operator;;
esac
