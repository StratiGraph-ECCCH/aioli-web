// Exécuté par l'image ArangoDB au premier démarrage (volume vide) : crée la base utilisée par aioli-data-api.
const db = require('@arangodb').db;
const name = require('internal').env.ARANGO_DB;

if (name && !db._databases().includes(name)) {
  db._createDatabase(name);
  print('Base ArangoDB créée : ' + name);
}
