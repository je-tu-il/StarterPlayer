# StarterPlayer / FingerPick

## Version de travail

Le projet Xcode `ios-fingerpick/FingerPick.xcodeproj` contient une app SwiftUI pour iOS 18 ou ultérieur. Ouvrir le schéma partagé **FingerPick**.

- **Tirage** : aléatoire, roue, dés, cartes, équipes, ordre aléatoire, rotation et équilibre basé sur l’historique. Le mode tactile accepte des doigts posés ensemble ou des touches successives. La dictée fonctionne sur l’iPhone lorsque la langue est disponible hors connexion.
- **Scores** : catalogue de 126 jeux, recherche et feuilles distinctes pour Yam’s, Yahtzee et Skull King. Les autres feuilles calculent les barèmes implémentés ou additionnent les sous-totaux spécifiques à l’édition.
- **Sauvegarde** : joueurs, parties et historique restent sur l’appareil. Le menu Sauvegarde exporte ou restaure ces données depuis Fichiers. Les archives JSON contiennent les noms et scores saisis en clair.

Pour lancer les suites, sélectionner un iPhone en simulateur et utiliser **Product → Test**. Le workflow macOS compile en Release après les tests. La soumission sur l’App Store requiert votre signature et une validation sur appareil.
