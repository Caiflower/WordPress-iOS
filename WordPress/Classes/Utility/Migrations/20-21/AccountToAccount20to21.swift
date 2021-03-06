import UIKit
import Foundation


/// Note:
/// This migration policy handles database migration from WPiOS 4.3 to 4.4
///
class AccountToAccount20to21: NSEntityMigrationPolicy {

    private let defaultDotcomUsernameKey    = "defaultDotcomUsernameKey"
    private let defaultDotcomKey            = "AccountDefaultDotcom"


    override func beginEntityMapping(mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        // Note:
        // NSEntityMigrationPolicy instance might not be the same all over. Let's use NSUserDefaults
        if let unwrappedAccount = legacyDefaultWordPressAccount(manager.sourceContext) {
            let username = unwrappedAccount.valueForKey("username") as! String

            let userDefaults = NSUserDefaults.standardUserDefaults()
            userDefaults.setValue(username, forKey: defaultDotcomUsernameKey)
            userDefaults.synchronize()

            DDLogSwift.logWarn(">> Migration process matched [\(username)] as the default WordPress.com account")
        } else {
            DDLogSwift.logError(">> Migration process couldn't locate a default WordPress.com account")
        }
    }

    override func endEntityMapping(mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        // Load the default username
        let userDefaults = NSUserDefaults.standardUserDefaults()
        let defaultUsername = userDefaults.stringForKey(defaultDotcomUsernameKey) ?? String()

        // Find the Default Account
        let context = manager.destinationContext
        let request = NSFetchRequest(entityName: "Account")
        let predicate = NSPredicate(format: "username == %@ AND isWpcom == true", defaultUsername)
        request.predicate = predicate

        let accounts = try context.executeFetchRequest(request) as! [NSManagedObject]

        if let defaultAccount = accounts.first {
            setLegacyDefaultWordPressAccount(defaultAccount)
            DDLogSwift.logInfo(">> Migration process located default account with username [\(defaultUsername)\")")
        } else {
            DDLogSwift.logError(">> Migration process failed to locate default account)")
        }

        // Cleanup!
        userDefaults.removeObjectForKey(defaultDotcomUsernameKey)
        userDefaults.synchronize()
    }


    // MARK: - Private Helpers

    private func legacyDefaultWordPressAccount(context: NSManagedObjectContext) -> NSManagedObject? {
        let objectURL = NSUserDefaults.standardUserDefaults().URLForKey(defaultDotcomKey)
        if objectURL == nil {
            return nil
        }

        let objectID = context.persistentStoreCoordinator!.managedObjectIDForURIRepresentation(objectURL!)
        if objectID == nil {
            return nil
        }

        var defaultAccount:NSManagedObject

        do {
            try defaultAccount = context.existingObjectWithID(objectID!)
        } catch {
            DDLogSwift.logError("\(error)")
            return nil
        }

        return defaultAccount
    }

    private func setLegacyDefaultWordPressAccount(account: NSManagedObject) {

        // Just in case
        if account.objectID.temporaryID {
            do {
                try account.managedObjectContext?.obtainPermanentIDsForObjects([account])
            } catch {}
        }

        let accountURL = account.objectID.URIRepresentation()

        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setURL(accountURL, forKey: defaultDotcomKey)
        defaults.synchronize()
    }
}
