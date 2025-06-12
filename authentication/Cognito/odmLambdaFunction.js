export const handler = function(event, context) {
  console.debug("enter in ODM lambda");
  // Allow to get debug information in the Watcher
  console.debug("context");
  console.debug(context);
  
  console.debug("event");
  console.debug(event);
  console.debug("clientId");
  console.debug(event.callerContext.clientId);

  console.debug("userAttributes");
  console.debug(event.request.userAttributes);

  var identity_for_access_token = event.callerContext.clientId;
  if (event.request.userAttributes.email != undefined) {
    console.debug("user email is defined. Use user email as claim identity for the access_token");
    identity_for_access_token = event.request.userAttributes.email 
  } else {
    console.debug("user email is undefined. Use clienId as claim identity for the access_token");
  }
  console.debug(identity_for_access_token);
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
  // Return to Amazon Cognito
  context.done(null, event);
};
