import Foundation

/**
 The data structure responsible for holding application state, allowing controlled mutation through dispatched
 `Actions` and notifying interested parties that `subscribe` to state changes.
 */
public final class Store<State>: Publisher, StateReading, Dispatcher {
    private let reduce: (State, Action) -> State

    private var state: State {
        didSet { publish(state) }
    }

    private var subscribers: [String: State -> Void]

    /**
     Initializes a `Store`.

     - parameter initialState: The initial value of the application state in hold.
     - parameter reducer: The root pure function that's responsible for transforming state according to `Actions`.
    */
    public init (initialState: State, reducer: (State, Action) -> State) {
        reduce = reducer
        state = initialState
        subscribers = [:]
    }

    /**
     Perform state changes described by the action and the root reducer.

     - parameter action: The descriptor of **what** is the state change.
     */
    public func dispatch(action: Action) {
        state = reduce(state, action)
    }

    /**
     Registers a handler that's called when state changes

     - parameter subscription: A closure that's called whenever there's a change to the state in hold.
     - returns: A closure that unsubscribes the provided subscription.
     */
    public func subscribe(subscription: State -> Void) -> (Void -> Void) {
        let token = NSUUID().UUIDString
        subscribers[token] = subscription

        subscription(state)

        return { [weak self] in
            self?.subscribers.removeValueForKey(token)
        }
    }

    private func publish(newState: State) {
        subscribers.values.forEach { $0(newState) }
    }

    public var getState: Void -> State {
        return { self.state }
    }
}

/**
 Defines state-reading capabilities.
 */

public protocol StateReading {
    associatedtype State
    
    /**
     Encloses the current state and provides a way to read hot snapshots
     of it.
    */
    var getState: Void -> State { get }
}

/**
 Defines `Action` dispatch capabilities. Instances conforming to `Dispatcher` are expected to know how to
 dispatch `Actions`.
 */

public protocol Dispatcher {
    /**
     Dispatches an action.

     - parameter action: The action that'll be dispatched.
    */
    func dispatch(action: Action)
}

extension Dispatcher {
    /**
     Executes a closure with an injected `dispatch` function. 
     Useful asynchronous `Action` dispatches.

     - parameter thunk: The closure that will be executed with an injected `dispatch` function.
     */
    public func dispatch(thunk: (Action -> Void) -> Void) {
        thunk(self.dispatch)
    }
}

extension Dispatcher where Self: StateReading {
    /**
     Executes a closure with an injected `dispatch` function and a state accessor. 
     Allows asynchronous `Action` dispatches as well as decisions based on
     the current state.

     - parameter thunk: The closure that will be executed with 
     an injected `dispatch` function and a state accessor.
     */
    public func dispatch(thunk: ((Action -> Void), (Void -> State)) -> Void) {
        thunk(dispatch, getState)
    }
}

/**
 Defines a mutation descriptor. Are typically associated to application actions and operations.
 */
public protocol Action {}

/**
 Instances conforming to `Publisher` are expected to know how to add handlers that are provided with an associated
 object in response to generic events.
 */
public protocol Publisher {
    associatedtype Publishing

    /**
     Adds a handler to a generic event.

     - parameter subscription: The handler that will be called in response to generic events.
     - returns: A closure that unsubscribes the provided subscription.
    */
    func subscribe(subscription: Publishing -> Void) -> Void -> Void
}
