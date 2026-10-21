# Cyberpunk TCG Deck Maker

Site statique (HTML/CSS/JS) qui génère des decks optimisés via Infomaniak AI Tools.

Un seul agent (le modèle choisi dans le sélecteur) pour toute la session : on discute de la stratégie avec lui, le bouton « Générer » lui demande le deck, puis on peut lui demander des modifications dans la conversation. Chaque deck qu'il propose est vérifié par le site (RAM, copies, taille) ; s'il y a des erreurs, l'agent les corrige, puis le site répare ce qui reste.

## Fichiers

- `index.html`, `style.css` : l'interface
- `js/cards.js` : chargement des cartes depuis l'API NetDeck
- `js/rules.js` : synthèse des règles pour le deckbuilding + définition des archétypes
- `js/engine.js` : légalité (RAM, copies, 40–50 cartes), score des cartes et des trios de Légendes, validation et réparation, export .txt
- `js/ai.js` : prompt système de l'agent (règles, cartes, deck actuel), appels Infomaniak, extraction du bloc deck
- `proxy.php` : relais vers l'API Infomaniak (elle bloque les appels directs depuis le navigateur, CORS)

## Hébergement

Dépose le dossier sur n'importe quel hébergement **avec PHP** (ex. hébergement web Infomaniak).
Pour garder le token côté serveur, copie `.env.example` en `.env` et remplis-le (le `.htaccess` bloque l'accès au `.env` depuis le web).
Sinon, saisis le token dans « Réglages API » sur la page : il est stocké dans le navigateur et transmis au proxy.

## En local

```sh
./start.sh   # crée le .env au premier lancement, puis démarre le serveur
```
