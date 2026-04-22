//
//  LogTouchIntent.swift
//  KeepInTouchWidget
//
//  Runs when the user taps the ✓ button on the medium widget. Writes a
//  new TouchEvent and updates the Person's lastTouchAt, then reloads
//  all widget timelines so the row disappears. Does not open the app.
//

import AppIntents
import CoreData
import Foundation
import WidgetKit

struct LogTouchIntent: AppIntent {
    static var title: LocalizedStringResource { "Log a touch" }
    static var description: IntentDescription { IntentDescription("Record that you reached out to this person.") }

    @Parameter(title: "Person")
    var personID: String

    init() {
        personID = ""
    }

    init(personID: UUID) {
        self.personID = personID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: personID) else {
            return .result()
        }

        guard let container = WidgetWritableCoreData.shared else {
            return .result()
        }

        try await container.performWrite { context in
            try Self.logTouch(personID: id, in: context, now: Date())
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    static func logTouch(personID: UUID, in context: NSManagedObjectContext, now: Date) throws {
        let personRequest = NSFetchRequest<NSManagedObject>(entityName: "Person")
        personRequest.predicate = NSPredicate(format: "id == %@", personID as CVarArg)
        personRequest.fetchLimit = 1

        guard let person = try context.fetch(personRequest).first else {
            return
        }

        person.setValue(now, forKey: "lastTouchAt")
        person.setValue(TouchMethod.other.rawValue, forKey: "lastTouchMethod")
        person.setValue(now, forKey: "modifiedAt")

        let touchEvent = NSEntityDescription.insertNewObject(forEntityName: "TouchEvent", into: context)
        touchEvent.setValue(UUID(), forKey: "id")
        touchEvent.setValue(personID, forKey: "personId")
        touchEvent.setValue(now, forKey: "at")
        touchEvent.setValue(TouchMethod.other.rawValue, forKey: "method")
        touchEvent.setValue(now, forKey: "createdAt")
        touchEvent.setValue(now, forKey: "modifiedAt")

        if context.hasChanges {
            try context.save()
        }
    }
}
