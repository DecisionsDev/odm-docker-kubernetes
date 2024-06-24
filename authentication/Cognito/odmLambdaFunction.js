const handler = async (event) => {
  // Allow to get debug information in the Watcher 
  console.debug(event.request.userAttributes);
  // Get User email value
  var user_email = event.request.userAttributes.email;
  console.debug(user_email);
  event.response = {
    claimsOverrideDetails: {
      claimsToAddOrOverride: {
        // Add a client_id claim with email value
        client_id: user_email,
      },
    },
  };

  return event;
};

export { handler };
