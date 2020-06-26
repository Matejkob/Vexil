//
//  FlagPole.swift
//  Vexil
//
//  Created by Rob Amos on 25/5/20.
//

#if !os(Linux)
import Combine
#endif

import Foundation

@dynamicMemberLookup
public class FlagPole<RootGroup> where RootGroup: FlagContainer {

    // MARK: - Configuration

    public let configuration: VexilConfiguration


    // MARK: - Sources

    public var sources: [FlagValueSource] {
        didSet {
            #if !os(Linux)

            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
                self.setupSnapshotPublishing(sendImmediately: true)
            }

            #endif
        }
    }

    public static var defaultSources: [FlagValueSource] {
        return [
            UserDefaults.standardx
        ]
    }


    // MARK: - Initialisation

    public init (hoist: RootGroup.Type, configuration: VexilConfiguration = .default, sources: [FlagValueSource]? = nil) {
        self._rootGroup = hoist.init()
        self.configuration = configuration
        self.sources = sources ?? Self.defaultSources
        self.decorateRootGroup()

        #if !os(Linux)

        if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) {
            self.setupSnapshotPublishing(sendImmediately: false)
        }

        #endif
    }


    // MARK: - Flag Management

    internal var _rootGroup: RootGroup

    public subscript<Value> (dynamicMember dynamicMember: KeyPath<RootGroup, Value>) -> Value {
        return self._rootGroup[keyPath: dynamicMember]
    }

    public subscript (dynamicMember dynamicMember: KeyPath<RootGroup, Bool>) -> Bool {
        return self._rootGroup[keyPath: dynamicMember]
    }

    private func decorateRootGroup () {
        let prefix = self.configuration.prefix ?? ""

        Mirror(reflecting: self._rootGroup)
            .children
            .lazy
            .decorated
            .forEach {
                $0.value.decorate(lookup: self, label: $0.label, codingPath: [ prefix ])
            }
    }


    // MARK: - Real Time Changes

    #if !os(Linux)

    private lazy var latestSnapshot = PassthroughSubject<Snapshot<RootGroup>, Never>()

    public var publisher: AnyPublisher<Snapshot<RootGroup>, Never> {
        self.latestSnapshot.eraseToAnyPublisher()
    }

    private lazy var cancellables = Set<AnyCancellable>()

    private func setupSnapshotPublishing (sendImmediately: Bool) {

        // cancel our existing one
        self.cancellables.forEach { $0.cancel() }
        self.cancellables.removeAll()

        let upstream = self.sources.compactMap { $0.valuesDidChange }
        guard upstream.isEmpty == false else { return }

        Publishers.MergeMany(upstream)
            .sink { [weak self] in
                guard let self = self else { return }
                self.latestSnapshot.send(self.snapshot())
            }
            .store(in: &self.cancellables)

        if sendImmediately {
            self.latestSnapshot.send(self.snapshot())
        }
    }

    #endif

    // MARK: - Snapshots

    public func snapshot () -> Snapshot<RootGroup> {
        return Snapshot(flagPole: self, copyCurrentFlagValues: true)
    }

    public func emptySnapshot () -> Snapshot<RootGroup> {
        return Snapshot(flagPole: self, copyCurrentFlagValues: false)
    }

    public func insert (snapshot: Snapshot<RootGroup>, at index: Array<FlagValueSource>.Index) {
        self.sources.insert(snapshot, at: index)

    }
    public func append (snapshot: Snapshot<RootGroup>) {
        self.sources.append(snapshot)
    }

    public func remove (snapshot: Snapshot<RootGroup>) {
        self.sources.removeAll(where: { ($0 as? Snapshot<RootGroup>) == snapshot })
    }


    // MARK: - Mutating Flag Sources

    public func save (snapshot: Snapshot<RootGroup>, to source: FlagValueSource) throws {
        try snapshot.allFlags()
            .filter { $0.isDirty == true }
            .forEach { try $0.save(to: source) }
    }
}
