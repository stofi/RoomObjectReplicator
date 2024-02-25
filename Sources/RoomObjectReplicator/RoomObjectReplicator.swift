//
//  RoomObjectReplicator.swift
//  RoomObjectReplicator
//
//  Created by Jack Mousseau on 6/6/22.
//

import ARKit
import RoomPlan

public enum RoomElementCategory {
    case object(CapturedRoom.Object.Category)
    case surface(CapturedRoom.Surface.Category)
}

public class RoomElementAnchor: ARAnchor {
    override public var identifier: UUID {
        roomElementIdentifier
    }

    override public var transform: simd_float4x4 {
        roomElementTransform
    }

    public private(set) var dimensions: simd_float3
    //    public private(set) var category: CapturedRoom.Object.Category
    public private(set) var category: RoomElementCategory

    private let roomElementIdentifier: UUID
    private var roomElementTransform: simd_float4x4

    public required init(anchor: ARAnchor) {
        guard let anchor = anchor as? RoomElementAnchor else {
            fatalError(
                "RoomObjectAnchor can only copy other RoomObjectAnchor instances"
            )
        }

        roomElementIdentifier = anchor.roomElementIdentifier
        roomElementTransform = anchor.roomElementTransform
        dimensions = anchor.dimensions
        category = anchor.category

        super.init(anchor: anchor)
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("Unavailable")
    }

    public init(_ object: CapturedRoom.Object) {
        roomElementIdentifier = object.identifier
        roomElementTransform = object.transform
        dimensions = object.dimensions
        category = .object(object.category)
        super.init(transform: object.transform)
    }

    fileprivate func update(_ object: CapturedRoom.Object) {
        roomElementTransform = object.transform
        dimensions = object.dimensions
        category = .object(object.category)
    }

    public init(_ surface: CapturedRoom.Surface) {
        roomElementIdentifier = surface.identifier
        roomElementTransform = surface.transform
        dimensions = surface.dimensions
        category = .surface(surface.category)
        super.init(transform: surface.transform)
    }

    fileprivate func update(_ surface: CapturedRoom.Surface) {
        roomElementTransform = surface.transform
        dimensions = surface.dimensions
        category = .surface(surface.category)
    }
}

public class RoomObjectReplicator {
    private var trackedAnchors: Set<RoomElementAnchor>
    private var trackedAnchorsByIdentifier: [UUID: RoomElementAnchor]
    private var inflightAnchors: Set<RoomElementAnchor>

    public init() {
        trackedAnchors = Set<RoomElementAnchor>()
        trackedAnchorsByIdentifier = [UUID: RoomElementAnchor]()
        inflightAnchors = Set<RoomElementAnchor>()
    }

    public func anchor(
        objects: [CapturedRoom.Object],
        surfaces: [CapturedRoom.Surface],
        in session: RoomCaptureSession
    ) {
        for object in objects {
            if
                let existingAnchor =
                trackedAnchorsByIdentifier[object.identifier]
            {
                existingAnchor.update(object)
                inflightAnchors.insert(existingAnchor)
                session.arSession.delegate?.session?(
                    session.arSession,
                    didUpdate: [existingAnchor]
                )
            }
            else {
                let anchor = RoomElementAnchor(object)
                inflightAnchors.insert(anchor)
                session.arSession.add(anchor: anchor)
            }
        }
        for surface in surfaces {
            if
                let existingAnchor =
                trackedAnchorsByIdentifier[surface.identifier]
            {
                existingAnchor.update(surface)
                inflightAnchors.insert(existingAnchor)
                session.arSession.delegate?.session?(
                    session.arSession,
                    didUpdate: [existingAnchor]
                )
            }
            else {
                let anchor = RoomElementAnchor(surface)
                inflightAnchors.insert(anchor)
                session.arSession.add(anchor: anchor)
            }
        }
        trackInflightAnchors(in: session)
    }

    private func trackInflightAnchors(in session: RoomCaptureSession) {
        trackedAnchors.subtracting(inflightAnchors)
            .forEach(session.arSession.remove)
        trackedAnchors.removeAll(keepingCapacity: true)
        trackedAnchors.formUnion(inflightAnchors)
        inflightAnchors.removeAll(keepingCapacity: true)
        trackedAnchorsByIdentifier.removeAll(keepingCapacity: true)

        for trackedAnchor in trackedAnchors {
            trackedAnchorsByIdentifier[trackedAnchor.identifier] = trackedAnchor
        }
    }
}
