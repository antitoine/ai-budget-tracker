# ✦ AI Budget Tracker & Widgets pour macOS

**AI Budget Tracker** permet de **suivre en temps réel l'évolution de vos dépenses et consommations IA** à travers **Cursor**, **Antigravity** et **Claude**, avec **deux formats de widgets dédiés à la zone droite de votre écran (Notifications & Bureau)** :

1. 📱 **Le Widget Apple Officiel (WidgetKit)** : directement intégré dans le **Centre de notifications macOS** (panneau latéral droit) et positionnable sur votre bureau.
2. 🪟 **Le Widget Flottant Latéral** : une carte en verre dépoli ultra-élégante qui se docke automatiquement sur le bord droit de votre écran, parfaite si votre barre des menus est encombrée !

![AI Budget Bar macOS](https://img.shields.io/badge/Platform-macOS%2014.0%2B-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)
![Design](https://img.shields.io/badge/UI-SwiftUI%20%26%20WidgetKit-purple)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 📸 Aperçu du Widget Latéral (Zone Notifications à droite)

```text
                                        ┌───────────────────────────────┐
                                        │ ✨ AI Budget Widget      ⚙️ ⨉ │
                                        ├───────────────────────────────┤
                                        │ 42,80 €       Octobre 2026    │
                                        │ sur 100 €     Reste: 57,20 €  │
                                        │ [██████████░░░░░░] 42.8%      │
                                        ├───────────────────────────────┤
                                        │ [</>] Cursor       21,60 € ↗  │
                                        │       265 / 500 requêtes      │
                                        │ [✨]  Antigravity  11,45 € ↗  │
                                        │       14 sessions (172k tok)  │
                                        │ [💬]  Claude       14,80 € ↗  │
                                        │       Sonnet 3.5 & 3.7        │
                                        ├───────────────────────────────┤
                                        │ 📊 Évolution sur 7 jours      │
                                        │     █    █         █          │
                                        │   █ █  █ █   █   █ █          │
                                        │  Lun Mar Mer Jeu Ven Sam Dim  │
                                        ├───────────────────────────────┤
                                        │ 🔄 Rafraîchir  (Bord droit)   │
                                        └───────────────────────────────┘
```

---

## ✨ Fonctionnalités Clés

1. **Intégration macOS native sans Dock (`LSUIElement`)** :
   - Se loge discrètement dans la barre des menus en haut de l'écran.
   - Affiche en direct le total du mois (`✨ 42.80 €`).
   - L'icône s'adapte automatiquement (vert/neutre sous le budget, orange à l'approche, rouge en cas de dépassement).

2. **Connexion 100% automatique aux 3 services** :
   - **Cursor** :
     - Supporte le cookie de session `WorkosCursorSessionToken` (récupère le compteur exact des requêtes rapides et du coût mensuel).
     - Supporte également les clés d'API Admin d'équipe (`api.cursor.com`).
     - Prise en compte du forfait fixe Pro (20 $/mois) + dépassements d'usage.
   - **Antigravity** :
     - **Scanneur local en temps réel** : analyse directement les journaux de sessions et transcripts locaux (`~/.gemini/antigravity/brain/*/transcript.jsonl`).
     - Calcule avec précision les tokens entrants, sortants et en cache (Gemini 2.5/3.8 Flash & Pro) et déduit le coût réel.
   - **Claude (Anthropic)** :
     - Se connecte à l'API Admin de facturation Anthropic (`/v1/organizations/cost_report` et `usage_report/messages`).
     - Prend en charge le forfait fixe Claude Pro mensuel si souhaité.

3. **Graphique d'évolution sur 7 jours** :
   - Mini diagramme à barres empilées montrant l'effort budgétaire de chaque outil au jour le jour.

4. **Alertes de seuils intelligentes** :
   - Notifications système macOS automatiques lors du franchissement de 50%, 80% ou 100% de votre enveloppe budgétaire.

5. **Double usage : Application Barre de Menus & Outil CLI** :
   - Peut être interrogé directement depuis le terminal (`AIBudgetBar --status` ou `AIBudgetBar --json`).

---

## 🚀 Installation & Lancement

### Méthode rapide (1 commande) :
Dans le dossier du projet, exécutez simplement :

```bash
make install
```

Cette commande compile l'application, l'installe dans `~/Applications/AIBudgetBar.app` et la lance immédiatement ! L'icône apparaît instantanément dans votre barre des menus.

### Autres commandes utiles :
```bash
make build    # Compile l'application dans ./build/AIBudgetBar.app
make status   # Affiche le récapitulatif directement dans le terminal
make json     # Exporte le résumé au format JSON
make clean    # Nettoie les fichiers de compilation
```

---

## ⚙️ Configuration des Clés & Services

Pour configurer vos accès, cliquez sur l'icône dans la barre des menus puis sur **⚙️ Préférences** (ou modifiez directement `~/.config/ai-budget-bar/config.json`) :

### 1. Cursor
- Rendez-vous sur [cursor.com/dashboard](https://www.cursor.com/dashboard)
- Ouvrez les Outils de développement du navigateur (`F12` ou `Inspecter`) > Onglet **Application** / **Stockage** > **Cookies** > `https://www.cursor.com`
- Copiez la valeur du cookie `WorkosCursorSessionToken` et collez-la dans les Préférences.

### 2. Antigravity
- Activé par défaut ! Le tracker local lit automatiquement vos sessions actives dans `~/.gemini/antigravity/brain`. Aucune clé requise.

### 3. Claude (Anthropic)
- Rendez-vous sur [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys)
- Créez ou copiez une clé d'administration de type `sk-ant-admin...` (nécessaire pour accéder aux rapports de coûts de l'organisation).

---

## 📁 Structure du Projet

```text
.
├── Makefile                     # Cibles make build, install, status
├── Package.swift                # Manifeste Swift Package
├── README.md                    # Documentation complète
├── Scripts/
│   ├── build.sh                 # Script de compilation et packaging .app
│   └── install.sh               # Installation dans ~/Applications & lancement
└── Sources/
    └── AIBudgetBar/
        ├── AppDelegate.swift    # Gestion du NSStatusItem, NSPopover et fenêtres
        ├── main.swift           # Point d'entrée CLI et GUI
        ├── Models/
        │   ├── AIService.swift    # Définition des services, couleurs, icônes
        │   ├── AppConfig.swift    # Persistance (~/.config/ai-budget-bar/config.json)
        │   └── ServiceUsage.swift # Modèles de consommation et historiques
        ├── Services/
        │   ├── AntigravityTracker.swift # Scanneur local de transcripts ~/.gemini
        │   ├── BudgetManager.swift      # Coordination, notifications et cache
        │   ├── ClaudeTracker.swift      # Client Anthropic Admin Cost Report API
        │   └── CursorTracker.swift      # Client Cursor API et cookies de session
        └── UI/
            ├── HistoryChartView.swift   # Graphique empilé 7 jours
            ├── PopoverView.swift        # Vue popover principale macOS
            ├── PreferencesView.swift    # Fenêtre complète des réglages
            └── ServiceRowView.swift     # Carte détaillée pour chaque service
```
