//
//  TutorialDemoData.swift
//  KeepInTouch
//
//  Hardcoded in-memory data for the demo PersonDetail shown during the
//  Walkthrough B tutorial. Nothing here is persisted to Core Data.
//

import Foundation

enum TutorialDemoData {
    private static let personID  = UUID(uuidString: "11111111-1111-1111-1111-111111111110")!
    private static let cadenceID = UUID(uuidString: "11111111-1111-1111-1111-111111111120")!
    private static let tagCollegeID = UUID(uuidString: "11111111-1111-1111-1111-111111111130")!
    private static let tagTravelID  = UUID(uuidString: "11111111-1111-1111-1111-111111111131")!
    private static let touchEvent1ID = UUID(uuidString: "11111111-1111-1111-1111-111111111140")!
    private static let touchEvent2ID = UUID(uuidString: "11111111-1111-1111-1111-111111111141")!

    /// Monthly is one of the four default cadences seeded by `DefaultDataSeeder`
    /// (`Weekly`, `Bi-Weekly`, `Monthly`, `Quarterly`). Using a real default
    /// keeps the demo PersonDetail consistent with what a fresh-install user
    /// sees in their own list.
    static let cadence = Cadence(
        id: cadenceID,
        name: "Monthly",
        frequencyDays: 30,
        warningDays: 5,
        colorHex: nil,
        isDefault: true,
        sortOrder: 2,
        createdAt: Date(),
        modifiedAt: Date()
    )

    static let tags: [Group] = [
        Group(
            id: tagCollegeID,
            name: "College",
            colorHex: "AA96DA",
            sortOrder: 0,
            createdAt: Date(),
            modifiedAt: Date()
        ),
        Group(
            id: tagTravelID,
            name: "Travel Buddy",
            colorHex: "4ECDC4",
            sortOrder: 1,
            createdAt: Date(),
            modifiedAt: Date()
        ),
    ]

    static var person: Person {
        let calendar = Calendar.current
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        return Person(
            id: personID,
            cnIdentifier: nil,
            displayName: "Alex Rivera",
            nickname: "Lex",
            initials: "AR",
            avatarColor: "6BCB77",
            cadenceId: cadenceID,
            groupIds: [tagCollegeID, tagTravelID],
            lastTouchAt: tenDaysAgo,
            lastTouchMethod: .text,
            lastTouchNotes: "Caught up about his Tokyo trip",
            nextTouchNotes: "Ask about Tokyo photos",
            isPaused: false,
            isTracked: true,
            notificationsMuted: false,
            customBreachTime: nil,
            snoozedUntil: nil,
            customDueDate: nil,
            birthday: Birthday(month: 11, day: 15, year: nil),
            birthdayNotificationsEnabled: true,
            contactUnavailable: false,
            isDemoData: false,
            cadenceAddedAt: nil,
            createdAt: Date(),
            modifiedAt: Date(),
            sortOrder: 0
        )
    }

    static var touchEvents: [TouchEvent] {
        let calendar = Calendar.current
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return [
            TouchEvent(
                id: touchEvent1ID,
                personId: personID,
                at: tenDaysAgo,
                method: .text,
                notes: "Caught up about his Tokyo trip",
                timeOfDay: nil,
                createdAt: tenDaysAgo,
                modifiedAt: tenDaysAgo
            ),
            TouchEvent(
                id: touchEvent2ID,
                personId: personID,
                at: thirtyDaysAgo,
                method: .call,
                notes: "Sunday catchup call",
                timeOfDay: nil,
                createdAt: thirtyDaysAgo,
                modifiedAt: thirtyDaysAgo
            ),
        ]
    }

    static var previewData: PersonDetailViewModel.PreviewData {
        PersonDetailViewModel.PreviewData(
            cadence: cadence,
            cadences: [cadence],
            groups: tags,
            touchEvents: touchEvents,
            phone: nil,
            email: nil,
            contactBirthday: nil
        )
    }
}
