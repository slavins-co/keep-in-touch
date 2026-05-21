//
//  StatsViewModel.swift
//  KeepInTouch
//

import Foundation

@MainActor
final class StatsViewModel: ObservableObject {

    enum LoadState: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    @Published var range: StatsRange
    @Published private(set) var snapshot: StatsSnapshot?
    @Published private(set) var loadState: LoadState = .idle

    private let personRepository: PersonRepository
    private let cadenceRepository: CadenceRepository
    private let touchEventRepository: TouchEventRepository
    private let calculator: StatsCalculator
    private let now: () -> Date

    init(
        personRepository: PersonRepository = CoreDataPersonRepository(context: CoreDataStack.shared.viewContext),
        cadenceRepository: CadenceRepository = CoreDataCadenceRepository(context: CoreDataStack.shared.viewContext),
        touchEventRepository: TouchEventRepository = CoreDataTouchEventRepository(context: CoreDataStack.shared.viewContext),
        calculator: StatsCalculator = StatsCalculator(),
        range: StatsRange = .days30,
        now: @escaping () -> Date = Date.init
    ) {
        self.personRepository = personRepository
        self.cadenceRepository = cadenceRepository
        self.touchEventRepository = touchEventRepository
        self.calculator = calculator
        self.range = range
        self.now = now
    }

    convenience init(dependencies: AppDependencies, range: StatsRange = .days30) {
        self.init(
            personRepository: dependencies.personRepository,
            cadenceRepository: dependencies.cadenceRepository,
            touchEventRepository: dependencies.touchEventRepository,
            range: range
        )
    }

    func load() {
        loadState = .loading
        let referenceDate = now()
        let rangeStart = Calendar.current.date(byAdding: .day, value: -range.dayCount + 1, to: Calendar.current.startOfDay(for: referenceDate))

        let people = personRepository.fetchAll()
        let cadences = cadenceRepository.fetchAll()
        let events = touchEventRepository.fetchAll(since: rangeStart)

        snapshot = calculator.compute(
            now: referenceDate,
            range: range,
            events: events,
            people: people,
            cadences: cadences
        )
        loadState = .ready
    }
}
