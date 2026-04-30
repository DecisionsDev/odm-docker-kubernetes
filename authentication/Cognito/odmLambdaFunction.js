export const handler = async (event, context) => {
  console.debug("enter in ODM lambda");
  console.debug("context=",  context);
  console.debug("event=",    event);
  console.debug("clientId=", event.callerContext.clientId);
  console.debug("userAttributes=", event.request.userAttributes);

  var identity_for_access_token;
  if (event.request.userAttributes.email != undefined) {
    console.debug("user email is defined. Using user email as claim identity for the access_token - Rule Designer Context");
    identity_for_access_token = event.request.userAttributes.email
  } else {
    console.debug("user email is undefined. Using clienId as claim identity for the access_token - M2M Context with client-credentials");
    identity_for_access_token = event.callerContext.clientId;
  }
  console.debug("identity=", identity_for_access_token);
  event.response = {
    "claimsAndScopeOverrideDetails": {
      "idTokenGeneration": {
        "claimsToAddOrOverride": {
          "identity": event.request.userAttributes.email
        }
      },
      "accessTokenGeneration": {
        "claimsToAddOrOverride": {
          "identity": identity_for_access_token
    }
      },
    }
  };
  return event;
};