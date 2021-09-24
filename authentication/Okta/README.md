
## Manage group and user
   * Menu Directory -> Groups
      * Click Add Group button
         * Name : odm-admin
         * Group Description : ODM Admin group

![Add Group](AddGroup.png)
        
   * Menu Directory -> People
      * Click 'Add Person' button
         * User type : User
         * First name : ``<YourFirstName>``
         * Last name : ``<YourLastName>``
         * Username : ``<YourFirstName>.<YourLastName>``
         * Primary email : ``<YourFirstName>.<YourLastName>@mycompany.com``
         * Groups (optional) : **odm-admin**
      * Click Save button 
      * Repeat for each user you want to add.

## Configure Claims
This section allows you augment the token by the useridentifier and group properties that will be used for the ODM authentication and authorization mechanism.
   * Menu Security -> api
      * Click default link of Authorization server
      ![Api Claim](ApiClaim.png)
      
      * Select claims tab
      * Click 'Add claim' button
        * Name : loginName
        * Include in token type : **Access Token**
        * Value : (appuser != null) ? appuser.userName : app.clientId
      * Click Create Button  
      * Click 'Add claim' button
        * Name : loginName
        * Include in token type : **Id Token**
        * Value : (appuser != null) ? appuser.userName : app.clientId
      * Click Create Button
      * Click 'Add claim' button
      * Name : groups
        * Include in token type : **Access Token**
        * Value type : Groups
        * Start with : odm-admin
      * Click Create Button
      * Click 'Add claim' button
      * Name : groups
        * Include in token type : **Access Token**
        * Value type : Groups
        * Start with : odm-admin
      * Click Create Button
      ![Add Claim Result](ResultAddClaims.png)

## Verify Token content 
You can verify the content of the token with the Token Preview pannel. 
You have to check that the login name and groups are available in the id token using the authorization flow which the flow used by ODM.
* Menu Security -> api
   *  Click default link of Authorization server
   *  Click the Token Preview
     *  OAuth/OIDC client : ODM Application
     *  Grant type : Authorization Code
     *  User: ``<YourEmailAddress>``
     *  Scopes : openid
   *  Clikc the Preview Token button
   * As result the id_token tab as well as in the token tab should contains  
   ``...
   "loginName": "<YourEmailAddress>",
  "groups": [
    "odm-admin"
  ]``
  ![Token Preview](TokenPreview.png)

Note that the discovery endpoint can be found in the settings tag Metadata URI. Menu Security -> api -> default (link) -> Metadata URI (link)

## Setup an Application 

   * Menu Applications -> Applications 
   * Click Create an App Integration
     * Select OIDC - OpenID Connect
     * Select WebApplication
     * Next
    ![Add Application](AddApplication.png)
    
   
   * Edit Application
     * App integration name : ODM Application
     * Grant type:
        * Check Client Credentials
        * Check Refresh Token
        * Implicit (hybrid) 
     * Assignments:
        * Controlled access:
           * Limit access to selected groups:
              * Selected group(s) : **odm-admin**    
     * Click Save button 
![New Web Application](NewWebAppIntegration.png)
