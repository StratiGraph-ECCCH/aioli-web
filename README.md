# Aïoli + aioli-data-api (Pour un déploiement local)


## Initialiser le dossier

```bash
./init.sh

Prépare ce dossier pour le premier démarrage :
  - crée .env à partir de .env.example et y renseigne HOST_PROJECT_PATH
  - extrait src/bin de l'image (nécessaire aux conteneurs de traitement lancés par Aïoli)
  - crée l'arborescence workspace/
  - vérifie la présence de l'image aioli-data-api
  - récupère les images de traitement (potreeconverter, matlab2017a, micmac)
 Usage : ./init.sh  (à relancer après chaque mise à jour de l'image aioli-web)
```


## Démarrer

** MERCI D'ADAPTER LES PORTS DANS .env et le fichier constants.json dans /conf**

```bash
docker compose up -d
docker compose ps
```

- Aïoli : `http://localhost:8080`
- Keycloak : `http://localhost:8081`
- API : `http://127.0.0.1:8001/docs` 
- ArangoDB : `http://127.0.0.1:8529` 

## Construction du docker Keycloak

1. Se connecter
```bash
login: admin
password: admin
```
2. Créer le realm du projet (dans mon cas "testAioli")

3. Créer un client AioliClient

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
3. Créer un user

### Construction de l'API Data-Access

1. Configurer Keycloak

- Créer le client `aioli-data-api` dans le realm existant. Ne pas activer de login interactif pour ce client. **IMPORTANT** Ajouter les **client roles** `synchronization` et `maintenance`.

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

# Dans l'onglet Roles
maintenance
synchronization
```


- Créer le client public `aioli-data-api-swagger` avec **Standard flow** activé et **PKCE S256**. Désactiver Direct Access Grants. Configurer **Valid redirect URIs** sur `https://PUBLIC-URL-OF-THE-API/docs/oauth2-redirect` (ou l'URL locale exacte pendant les tests) et les Web origins correspondantes.

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

- Configurer un Audience mapper pour que les access tokens destinés à DataAPi contiennent  `aioli-data-api` dans le champ `aud`.

**NB :**
	- `aud` (audience) : indique que le token est destiné à notre API `aioli-data-api`.
	- `resource_access` (rôles) : indique si l'utilisateur possède les rôles `synchronization` et/ou `maintenance`.

Par exemple, un administrateur connecté via Swagger devrait obtenir un token contenant quelque chose comme :

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

Il s'agit d'un extrait simplifié : le véritable token contient d'autres champs, notamment `iss`, `exp` et `azp`.

- Dans la console d'administration Keycloak :

1. Aller dans Clients → `aioli-data-api-swagger`.
2. Ouvrir l'onglet Client scopes.
3. Cliquer sur le scope dédié au client, généralement nommé `aioli-data-api-swagger-dedicated`.
4. Ouvrir l'onglet Mappers, puis cliquer sur Configure a new mapper.
5. Sélectionner Audience et renseigner les champs suivants :

|Champ|Valeur|
|---|---|
|Name|`aioli-data-api-audience`|
|Included Client Audience|`aioli-data-api`|
|Included Custom Audience|Laisser vide|
|Add to access token|Activé|
|Add to ID token|Désactivé, si proposé|

2. Enregistrer avec Save.

Ce mapper indique à Keycloak que les access tokens délivrés au client Swagger sont également destinés à DataAPI.

3. Attribuer les rôles aux users qui auront le statut d'administrateurs : Aller dans Users → ton utilisateur → Role mapping → Assign role et ajouter les rôles `synchronization` et `maintenance`.

**NB** Pour vérifier le client scope `roles` :

Retourner dans Clients → `aioli-data-api-swagger` → Client scopes. et Vérifier que le scope `roles` est bien associé au client, idéalement avec le type Default.
On peut aussi aller dans Client scopes → roles → Mappers et vérifier la présence du mapper client roles. Il est normalement préconfiguré pour écrire les rôles dans `resource_access.${client_id}.roles`. Si Full scope allowed est désactivé pour Swagger, il faudra aussi autoriser explicitement les rôles `aioli-data-api` dans ses role scope mappings.

4. pour vérifier le résultat
- aller dans Clients → `aioli-data-api-swagger` → Client scopes.
- Ouvrir Evaluate et sélectionner l'utilisateur administrateur dans le champ Users.
- Cliquer sur Generated access token (ou l'équivalent selon ta version).
- On devrait retrouver : Exemple de l'access token attendu

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

5. Accès au swagger et test :

Dans mon cas, j'y accède à http://localhost:8000/docs
Cliquer sur **Authorize** et encore **Authorize*** tout en bas de la modale et tester les endpoints

  ## NB : Si vous utilisez déjà sur votre serveur :

  - couchdb
  -  keycloak
  - arangodb
  
  Merci de les commenter dans le fichier docker-compose et d'adapter le fichier .env