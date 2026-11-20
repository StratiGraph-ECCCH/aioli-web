# Aïoli + aioli-data-api (For local deployment)


## Initialize the folder

```bash
./init.sh
```

Prepares this folder for first startup:
  - creates .env from .env.example and fills in HOST_PROJECT_PATH
  - extracts src/bin from the image (required by the processing containers launched by Aïoli)
  - creates the workspace/ directory structure
  - checks for the presence of the aioli-data-api image
  - pulls the processing images (potreeconverter, matlab2017a, micmac)

Usage: `./init.sh`  (rerun after each aioli-web image update)



## Start

**PLEASE ADJUST THE PORTS IN .env and the constants.json file in /conf**

```bash
docker compose up -d
docker compose ps
```

- Aïoli: `http://localhost:8080`
- Keycloak: `http://localhost:8081`
- API: `http://127.0.0.1:8001/docs`
- ArangoDB: `http://127.0.0.1:8529`

## Building the Keycloak docker

1. Log in
```bash
login: admin
password: admin
```
2. Create the project realm (in my case "testAioli")

3. Create an AioliClient client

```
Client ID : AioliClient
Root URL : http://localhost:8080
Home URL : http://localhost:8080
Valid redirect URIs : http://localhost:8080/_proc/keycloak_callback and add  http://localhost:8080/*
Valid post logout redirect URIs : http://localhost:8080
Web origins : http://localhost:8080
Admin URL : http://localhost:8080

Client authentication : ON
Authorization : OFF
Authentication flow : Standard flow
PKCE Method : -
Require DPoP bound tokens : OFF
```
3. Create a user

### Building the Data-Access API

1. Configure Keycloak

- Create the `aioli-data-api` client in the existing realm. Do not enable interactive login for this client. **IMPORTANT** Add the **client roles** `synchronization` and `maintenance`.

```
Client ID : aioli-data-api
Root URL :
Home URL :
Valid redirect URIs : /*
Valid post logout redirect URIs :
Web origins : /*
Admin URL :

Client authentication : OFF
Authorization : OFF
Authentication flow : Standard flow
PKCE Method : -
Require DPoP bound tokens : OFF

# In the Roles tab
maintenance
synchronization
```


- Create the public client `aioli-data-api-swagger` with **Standard flow** enabled and **PKCE S256**. Disable Direct Access Grants. Set **Valid redirect URIs** to `https://PUBLIC-URL-OF-THE-API/docs/oauth2-redirect` (or the exact local URL during testing) and the corresponding Web origins.

```
Client ID : aioli-data-api-swagger
Root URL : http://localhost:8000
Home URL : http://localhost:8000
Valid redirect URIs : http://localhost:8000/docs/oauth2-redirect
Valid post logout redirect URIs : http://localhost:8000/docs/oauth2-redirect
Web origins : http://localhost:8000
Admin URL : http://localhost:8000

Client authentication : OFF
Authorization : OFF
Authentication flow : Standard flow
PKCE Method : S256
Require DPoP bound tokens : OFF
```

- Configure an Audience mapper so that access tokens intended for DataAPI contain `aioli-data-api` in the `aud` field.

**NB :**
	- `aud` (audience): indicates that the token is intended for our API `aioli-data-api`.
	- `resource_access` (roles): indicates whether the user has the roles `synchronization` and/or `maintenance`.

For example, an administrator logged in via Swagger should get a token containing something like:

```
{
  "sub": "a605f92c-xxxx-xxxx-xxxx-b133df55fa56",
  "aud": [
    "aioli-data-api"
  ],
  "resource_access": {
    "aioli-data-api": {
      "roles": [
        "synchronization",
        "maintenance"
      ]
    }
  }
}
```

This is a simplified excerpt: the actual token contains other fields, notably `iss`, `exp` and `azp`.

- In the Keycloak admin console:

1. Go to Clients → `aioli-data-api-swagger`.
2. Open the Client scopes tab.
3. Click on the client-dedicated scope, usually named `aioli-data-api-swagger-dedicated`.
4. Open the Mappers tab, then click on Configure a new mapper.
5. Select Audience and fill in the following fields:

|Field|Value|
|---|---|
|Name|`aioli-data-api-audience`|
|Included Client Audience|`aioli-data-api`|
|Included Custom Audience|Leave empty|
|Add to access token|Enabled|
|Add to ID token|Disabled, if offered|

2. Save with Save.

This mapper tells Keycloak that access tokens issued to the Swagger client are also intended for DataAPI.

3. Assign roles to users who will have administrator status: Go to Users → your user → Role mapping → Assign role and add the roles `synchronization` and `maintenance`.

**NB** To verify the `roles` client scope:

Go back to Clients → `aioli-data-api-swagger` → Client scopes. and verify that the `roles` scope is properly associated with the client, ideally with type Default.
You can also go to Client scopes → roles → Mappers and check for the presence of the client roles mapper. It is normally preconfigured to write roles into `resource_access.${client_id}.roles`. If Full scope allowed is disabled for Swagger, you will also need to explicitly allow the `aioli-data-api` roles in its role scope mappings.

4. To verify the result
- go to Clients → `aioli-data-api-swagger` → Client scopes.
- Open Evaluate and select the administrator user in the Users field.
- Click on Generated access token (or the equivalent depending on your version).
- You should find: Example of the expected access token

```json
{
  "aud": ["aioli-data-api"],
  "resource_access": {
    "aioli-data-api": {
      "roles": [
        "synchronization",
        "maintenance"
      ]
    }
  }
}
```

5. Swagger access and test:

In my case, I access it at http://localhost:8000/docs
Click **Authorize** and again **Authorize** at the very bottom of the modal, then test the endpoints

  ## NB: If you are already using on your server:

  - couchdb
  - keycloak
  - arangodb

  Please comment them out in the docker-compose file and adapt the .env file
