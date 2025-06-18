import Foundation
import FirebaseFirestore
// Assuming ListenerRegistrationProtocol is available

// Wrapper for Firebase's ListenerRegistration
class FirebaseListenerRegistration: ListenerRegistrationProtocol {
    private var firebaseListener: FirebaseFirestore.ListenerRegistration?

    init(_ firebaseListener: FirebaseFirestore.ListenerRegistration?) {
        self.firebaseListener = firebaseListener
    }

    func remove() {
        firebaseListener?.remove()
        firebaseListener = nil // Help break potential retain cycles if any
        print("FirebaseListenerRegistration: Listener removed.")
    }

    deinit {
        // Ensure listener is removed if this object is deallocated,
        // though explicit removal is preferred.
        remove()
        print("FirebaseListenerRegistration deinit.")
    }
}
