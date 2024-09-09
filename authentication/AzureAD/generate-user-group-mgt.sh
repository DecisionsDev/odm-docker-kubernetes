#!/bin/bash

# Function to display help message
usage() {
    echo "Usage: $0 -t TENANT_ID -i CLIENT_ID -x CLIENT_SECRET [-v]"
    echo "Options:"
    echo "  -t    Azure AD Tenant ID"
    echo "  -i    Azure AD Client ID"
    echo "  -x    Azure AD Client Secret"
    echo "  -v    Enable verbose output to display extracted users and groups"
    echo "  -h    Display this help message"
    exit 1
}

# Initialize verbose flag
VERBOSE=false

# Check if no arguments are passed
if [ "$#" -eq 0 ]; then
    usage
fi

# Parse command-line options
while getopts ":t:i:x:vh" opt; do
    case $opt in
        t)
            TENANT_ID="$OPTARG"
            ;;
        i)
            CLIENT_ID="$OPTARG"
            ;;
        x)
            CLIENT_SECRET="$OPTARG"
            ;;
        v)
            VERBOSE=true
            ;;
        h)
            usage
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            usage
            ;;
    esac
done

# Check if all required parameters are provided
if [ -z "$TENANT_ID" ] || [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
    echo "Error: Missing required parameters."
    usage
fi

# Function to URL encode the data
urlencode() {
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c"
        esac
    done
}

# Step 1: Get Access Token
echo "Getting access token..."
ACCESS_TOKEN=$(curl -s --location --request POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
--header "Content-Type: application/x-www-form-urlencoded" \
--data-urlencode "client_id=$CLIENT_ID" \
--data-urlencode "scope=https://graph.microsoft.com/.default" \
--data-urlencode "client_secret=$CLIENT_SECRET" \
--data-urlencode "grant_type=client_credentials" | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ]; then
    echo "Failed to obtain access token."
    exit 1
fi
echo $ACCESS_TOKEN

# Step 2: Get User Data
echo "Fetching user data..."
USER_NAMES=$(curl -s --location --request GET "https://graph.microsoft.com/v1.0/users?\$select=mail,displayName,id" \
--header "Authorization: Bearer $ACCESS_TOKEN")

# Display users if verbose mode is enabled
if [ "$VERBOSE" = true ]; then
    echo "Extracted Users:"
    echo "$USER_NAMES" | jq -r '.value[] | "\(.displayName) (\(.mail))"'
fi

# Step 3: Get Group Data
echo "Fetching group data..."
GROUP_ENTRAID=$(curl -s --location --request GET "https://graph.microsoft.com/v1.0/groups?\$select=displayName" --header "Authorization: Bearer $ACCESS_TOKEN")
GROUP_NAMES=$(echo $GROUP_ENTRAID | jq -r '.value[] | .displayName')
# Display groups if verbose mode is enabled
if [ "$VERBOSE" = true ]; then
    echo "Extracted Groups:"
    echo "Groups : $GROUP_NAMES"
fi


# Initialize the XML content
XML_CONTENT="<dc-usermanagement>"

# Generate role and group XML
echo "Generating XML for roles and groups..."

for group_name in $GROUP_NAMES; do
    XML_CONTENT+="\n <group name=\"$group_name\" roles=\"rtsUser\"/>"
done

# Process users
echo "Generating XML for users..."
USER_ENTRIES=$(echo $USER_NAMES | jq -c '.value[] | { id: .id , mail: .mail}')
for user in $USER_ENTRIES; do
#    NAME=$(echo $user | jq -r '.name')
    EMAIL=$(echo $user | jq -r '.mail')
    ID=$(echo $user | jq -r '.id')

    GROUPS_FOR_USER=$(curl -s --location --request GET "https://graph.microsoft.com/v1.0/users/$ID/memberOf" \
--header "Authorization: Bearer $ACCESS_TOKEN")
    
    # Use jq to extract displayName values, excluding "Global Administrator"
    group_names_bis=$(echo "$GROUPS_FOR_USER" | jq -r '.value[].displayName' | grep -v "Global Administrator")

    # Join the group names with commas
    commasGroups=$(echo "$group_names_bis" | paste -sd "," -)
    # Iterate over the extracted displayName values
    if [ "$VERBOSE" = true ]; then
        echo "GROUPS FOR USER : $EMAIL -->  $commasGroups"
    fi

    
    # Add user XML entry
    XML_CONTENT+="\n <user name=\"$EMAIL\" groups=\"$commasGroups\"/>"
done

# Close the XML
XML_CONTENT+="\n</dc-usermanagement>"

# Output the XML to a file
echo "Writing XML to output file..."
echo -e "$XML_CONTENT" > usermanagement.xml

echo "Script completed. XML file 'usermanagement.xml' generated successfully."
