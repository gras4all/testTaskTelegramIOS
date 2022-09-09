import Foundation
import UIKit
import TelegramCore
import SwiftSignalKit
import Display

enum TestTaskCallListNodeLocation: Equatable {
    case initial(count: Int)
    case changeType(index: EngineMessage.Index)
    case navigation(index: EngineMessage.Index)
    case scroll(index: EngineMessage.Index, sourceIndex: EngineMessage.Index, scrollPosition: ListViewScrollPosition, animated: Bool)
    
    static func ==(lhs: TestTaskCallListNodeLocation, rhs: TestTaskCallListNodeLocation) -> Bool {
        switch lhs {
            case let .navigation(index):
                switch rhs {
                    case .navigation(index):
                        return true
                    default:
                        return false
                }
            default:
                return false
        }
    }
}

struct TestTaskCallListNodeLocationAndType: Equatable {
    let location: TestTaskCallListNodeLocation
    let scope: EngineCallList.Scope
}

enum TestTaskCallListNodeViewUpdateType {
    case Initial
    case Generic
    case Reload
    case ReloadAnimated
    case UpdateVisible
}

struct TestTaskCallListNodeViewUpdate {
    let view: EngineCallList
    let type: TestTaskCallListNodeViewUpdateType
    let scrollPosition: TestTaskCallListNodeViewScrollPosition?
}

func callListViewForLocationAndType(locationAndType: TestTaskCallListNodeLocationAndType, engine: TelegramEngine) -> Signal<(TestTaskCallListNodeViewUpdate, EngineCallList.Scope), NoError> {
    switch locationAndType.location {
    case let .initial(count):
        return engine.messages.callList(
            scope: locationAndType.scope,
            index: EngineMessage.Index.absoluteUpperBound(),
            itemCount: count
        )
        |> map { view -> (TestTaskCallListNodeViewUpdate, EngineCallList.Scope) in
            return (TestTaskCallListNodeViewUpdate(view: view, type: .Generic, scrollPosition: nil), locationAndType.scope)
        }
    case let .changeType(index):
        return engine.messages.callList(
            scope: locationAndType.scope,
            index: index,
            itemCount: 120
        )
        |> map { view -> (TestTaskCallListNodeViewUpdate, EngineCallList.Scope) in
            return (TestTaskCallListNodeViewUpdate(view: view, type: .ReloadAnimated, scrollPosition: nil), locationAndType.scope)
        }
    case let .navigation(index):
        var first = true
        return engine.messages.callList(
            scope: locationAndType.scope,
            index: index,
            itemCount: 120
        )
        |> map { view -> (TestTaskCallListNodeViewUpdate, EngineCallList.Scope) in
            let genericType: TestTaskCallListNodeViewUpdateType
            if first {
                first = false
                genericType = .UpdateVisible
            } else {
                genericType = .Generic
            }
            return (TestTaskCallListNodeViewUpdate(view: view, type: genericType, scrollPosition: nil), locationAndType.scope)
        }
    case let .scroll(index, sourceIndex, scrollPosition, animated):
        let directionHint: ListViewScrollToItemDirectionHint = sourceIndex > index ? .Down : .Up
        let callScrollPosition: TestTaskCallListNodeViewScrollPosition = .index(index: index, position: scrollPosition, directionHint: directionHint, animated: animated)
        var first = true
        return engine.messages.callList(
            scope: locationAndType.scope,
            index: index,
            itemCount: 120
        )
        |> map { view -> (TestTaskCallListNodeViewUpdate, EngineCallList.Scope) in
            let genericType: TestTaskCallListNodeViewUpdateType
            let scrollPosition: TestTaskCallListNodeViewScrollPosition? = first ? callScrollPosition : nil
            if first {
                first = false
                genericType = .UpdateVisible
            } else {
                genericType = .Generic
            }
            return (TestTaskCallListNodeViewUpdate(view: view, type: genericType, scrollPosition: scrollPosition), locationAndType.scope)
        }
    }
}
