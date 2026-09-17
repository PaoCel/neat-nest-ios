import SwiftUI
import FirebaseCore
import FirebaseAuth
import UserNotifications
import UIKit
import GoogleSignIn
import AppIntents

// MARK: - App Delegate and Main App
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()

        UNUserNotificationCenter.current().delegate = PurchaseNotificationHandler.shared

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Errore nella richiesta di autorizzazione per le notifiche: \(error)")
            }
        }
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct NeatNestApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var userSession = UserSession()
    @StateObject private var voiceManager = SmartGroceryVoiceManager()
    @State private var hasCheckedSession = false

    var body: some Scene {
        WindowGroup {
            Group {
                if userSession.isLoggedIn {
                    MainMenuView()
                        .environmentObject(userSession)
                        .environmentObject(voiceManager)
                        .task(id: userSession.currentUserId) {
                            await processPendingVoiceRequestIfPossible()
                        }
                } else if userSession.pendingProfile != nil {
                    CompleteProfileView()
                        .environmentObject(userSession)
                } else {
                    LoginView()
                        .environmentObject(userSession)
                }
            }
            .task {
                guard !hasCheckedSession else { return }
                hasCheckedSession = true
                userSession.startAuthStateListener()
                userSession.checkUserSession()
                NeatNestSmartGroceryShortcuts.updateAppShortcutParameters()
                await PurchaseDetectionManager.shared.start()
            }
            .onChange(of: scenePhase, perform: { newPhase in
                guard newPhase == .active else { return }

                _Concurrency.Task {
                    await processPendingVoiceRequestIfPossible()
                }
            })
        }
    }

    private func processPendingVoiceRequestIfPossible() async {
        guard userSession.isLoggedIn else { return }
        await voiceManager.processPendingRequestIfPossible(userId: userSession.currentUserId)
    }
}
