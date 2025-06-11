export const handler = function(event, context) {
  console.debug("enter in ODM lambda");
  // Allow to get debug information in the Watcher
  console.debug("context");
  console.debug(context);
  
  console.debug("event");
  console.debug(event);

  console.debug("get clientId");
  console.debug(event.callerContext.clientId);
  

  console.debug(event.request.userAttributes);
  // Get User email value
  var user_email = event.request.userAttributes.email;
  console.debug(user_email);
  event.response = {
    "claimsAndScopeOverrideDetails": {
      "idTokenGeneration": {
        "claimsToAddOrOverride": {
          "family_name": "Doe",
          "identity": user_email
    }
      },
      "accessTokenGeneration": {
        "claimsToAddOrOverride": {
          "family_name": "Doe",
          "identity": event.callerContext.clientId
    }
      },
    }
  };
  // Return to Amazon Cognito
  context.done(null, event);
};
