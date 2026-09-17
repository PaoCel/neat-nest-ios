# Neat Nest (iOS)

Un'app per gestire la casa: dispensa, liste della spesa, ricette, budget e spese.
Il punto di partenza è lo scontrino: lo fotografi, l'app legge le righe, capisce
cosa hai comprato e aggiorna dispensa e spese da sola.

Stato: 1.0 (build 10) in TestFlight. Non ancora sull'App Store. Sviluppo iniziato
a marzo 2026.

## Come funziona

1. **Scontrino** → OCR con Vision (`VNRecognizeTextRequest`), parser delle righe
   (`ReceiptTextParser`), categorie (`ReceiptCategoryInferrer`) e triage dei casi
   dubbi (`ReceiptTriage`) prima di scrivere qualcosa.
2. **Dispensa**: quantità, livelli e scadenze stimate (`ShelfLifeCatalog`), con una
   previsione di quando ricomprare (`RepurchasePredictor`).
3. **Spesa**: liste con suggerimenti (`ShoppingRecommendationEngine`), prezzi per
   negozio (`RetailerPricingProvider`) e voci scritte a parole, interpretate da
   Foundation Models (`GroceryIntelligentParser`) con un parser deterministico di
   riserva (`GroceryPhraseParser`) quando il modello non c'è.
4. **Ricette** abbinate a quello che c'è in dispensa (`RecipeMatcher`).
5. **Budget e money**: mensilità, transazioni reali contro pianificato, area
   protetta con Face ID.

Acquisti e liste si possono aggiungere anche da Siri e Comandi rapidi (App Intents).

## Stack

SwiftUI, iOS 17, `@Observable`. Firebase Auth (email, Google, Sign in with Apple),
Firestore e Realtime Database. Vision e VisionKit, Foundation Models, AppIntents,
Swift Charts, MapKit e CoreLocation, LocalAuthentication, UserNotifications.
Progetto generato con XcodeGen; dipendenze via Swift Package Manager (Firebase iOS
SDK, GoogleSignIn, KeychainAccess).

```
NeatNest/
  App/          ingresso, sessione utente, App Intents
  Managers/     servizi e repository: Pantry, SmartGrocery, Receipts, Budget
  Models/
  ViewModels/   Pantry, SmartGrocery, Receipts, Recipes, Money, Budget
  Views/        Auth, Main, Pantry, Shopping, ShoppingList, SmartGrocery,
                Receipts, Recipes, Purchase, Money, Budget, Tasks, Profile
NeatNestTests/  150 test XCTest su parser, dispensa, prezzi, previsioni, ricette
```

## Build

```bash
xcodegen generate
```

`GoogleService-Info.plist` non è nel repo: va nella radice del progetto prima di
generare. Poi schema `NeatNest` in Xcode. I test girano con ⌘U.

Testi e nomi nel codice sono in italiano.
