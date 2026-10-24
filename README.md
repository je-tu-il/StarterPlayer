# 🎲 FingerPick (StarterPlayer) — Compagnon iOS Ultime de Jeux de Société

[![Release](https://img.shields.io/github/v/release/je-tu-il/StarterPlayer?color=purple&label=Version)](https://github.com/je-tu-il/StarterPlayer/releases/latest)
[![Build iOS](https://github.com/je-tu-il/StarterPlayer/actions/workflows/build.yml/badge.svg)](https://github.com/je-tu-il/StarterPlayer/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform: iOS](https://img.shields.io/badge/Plateforme-iPhone%20%7C%20iPad%20(iOS%2017%2B)-black.svg)](https://github.com/je-tu-il/StarterPlayer/releases/latest)

> **FingerPick** est une application iOS moderne et intuitive développée en **SwiftUI** qui sublime vos soirées jeux de société. Désignez le premier joueur au doigt, calculez automatiquement les scores de **Skull King** et du **Yam's**, et pilotez les points à la voix !

---

## 📲 Téléchargement Direct & Installation (Pour tous)

Téléchargez la dernière version compilée sur la page [**Releases GitHub**](https://github.com/je-tu-il/StarterPlayer/releases/latest) :

1. Téléchargez le fichier **`fingerpick.ipa`**.
2. Installez-le sur votre iPhone ou iPad en quelques secondes :
   - 🍏 **Via AltStore / SideStore** : Ouvrez l'application AltStore/SideStore sur votre iPhone, onglet *My Apps* > bouton `+` > sélectionnez `fingerpick.ipa`.
   - 💻 **Via Sideloadly** : Glissez `fingerpick.ipa` dans Sideloadly sur votre Mac ou PC, entrez votre identifiant Apple et cliquez sur *Start*.
   - ⚡ **Via TrollStore** : Ouvrez directement le fichier `.ipa` dans TrollStore (pour appareils compatibles).

---

## ✨ Modules & Fonctionnalités

### 👆 1. Finger Picker (Sélecteur de Premier Joueur)
- Posez chacun un doigt sur l'écran tactile.
- Des halos de particules lumineux s'illuminent sous chaque doigt.
- Après un suspense de 3 secondes, l'application sélectionne aléatoirement et désigne le joueur qui commence la partie !

### 🏴‍☠️ 2. Feuille de Score Skull King
- Suivi automatisé des paris (plis annoncés) et plis remportés manche par manche (manches 1 à 10).
- Calcul exact des bonus pirates, cartes sirènes, Skull King et butins.
- Prise en compte immédiate du zéro pli réussi ou manqué (-10 pts × n° manche).

### 🎲 3. Feuille de Score Yam's / Yahtzee
- Grille complète avec partie supérieure (As, Deux, Trois, Quatre, Cinq, Six) et calcul automatique du bonus de 35 points si total ≥ 63.
- Partie inférieure : Brelan, Carré, Full (25 pts), Petite Suite (30 pts), Grande Suite (40 pts), Yam's (50 pts), Chance.
- Pavé numérique interactif fluide et validation instantanée.

### 🎙️ 4. Saisie Vocale des Points (Voice-First)
- Pilotez la feuille de marque sans lâcher vos cartes ni toucher l'écran grâce à `SpeechRecognizerManager` (reconnaissance vocale Apple locale).

---

## 🛠️ Stack Technique

- **Langage** : Swift 5.9+ / SwiftUI
- **Frameworks** : Speech, AVFoundation, Combine, CoreHaptics
- **Cible** : iOS 17.0+ (iPhone & iPad)
- **CI/CD** : GitHub Actions (compilation automatique Release IPA sous macOS)

---

## 💻 Compilation avec Xcode

```bash
# Cloner le dépôt
git clone https://github.com/je-tu-il/StarterPlayer.git
cd StarterPlayer/ios-fingerpick

# Ouvrir dans Xcode
open FingerPick.xcodeproj
```
Sélectionnez votre appareil cible et appuyez sur **Run (Cmd + R)**.

---

## 📄 Licence

Projet distribué sous licence **MIT**. Voir le fichier [LICENSE](LICENSE) pour plus d'informations.
