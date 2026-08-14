//! The in-process, non-durable half of `#1295`'s capability-facing API
//! surface: `emit_event`.
//!
//! `#1295`'s scope, verbatim: *"`emit_event` is in-process and non-durable —
//! it is explicitly **not** a persistence path, and that must be stated so
//! nobody uses it as one."* This module is that statement made mechanical
//! rather than only documented:
//!
//! - [`EventBus::publish`] never touches [`crate::runtime::OperationLog`] or
//!   [`crate::content::ContentStore`] — there is no `std::fs` anywhere in
//!   this file, grep-verified the same way [`crate::notes`]'s conformance
//!   test verifies it for `NotesCapability`.
//! - A subscriber that is not listening when [`EventBus::publish`] runs
//!   simply misses the event. There is no queue-forever buffer, no replay,
//!   no way to ask "what did I miss while I was gone" — that question only
//!   has an answer for operations, via [`crate::runtime::Runtime::replay`].
//! - Restarting the process (or even just dropping every [`EventBus`]
//!   subscriber and creating a new one) loses every event that was ever
//!   published. Nothing here claims otherwise.
//!
//! A capability that needs the *other* thing — "this must still be true
//! after a restart, and every device must agree on it" — wants an Operation,
//! not an event. That is exactly the distinction `#1295` draws, and exactly
//! why `emit_event` and `create_operation` are two different functions on
//! [`crate::capability_api::CapabilityApi`] rather than one with a durability
//! flag.

use std::sync::mpsc::{self, Receiver, Sender};
use std::sync::Mutex;

/// One event, as a live subscriber observes it. Carries the emitting
/// capability's id (so a listener fanning in events from many capabilities
/// can tell them apart) and a free-form `topic` the capability chooses —
/// `C5`: the runtime knows no domains, so it does not interpret `topic` or
/// `payload` at all, only routes them.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CapabilityEvent {
    pub capability: String,
    pub topic: String,
    pub payload: Vec<u8>,
}

/// Fan-out publish, in-process, best-effort. Every [`Self::subscribe`] call
/// registers a fresh channel; [`Self::publish`] sends to every channel still
/// alive and silently drops any whose receiver has gone away — the bus never
/// accumulates dead subscribers, and never blocks a publisher on a slow or
/// absent listener beyond the channel's own (unbounded) queuing.
#[derive(Default)]
pub struct EventBus {
    subscribers: Mutex<Vec<Sender<CapabilityEvent>>>,
}

impl EventBus {
    pub fn new() -> Self {
        Self::default()
    }

    /// Registers a new listener and returns the `Receiver` half. There is no
    /// unsubscribe call — a subscriber that wants to stop listening simply
    /// drops the `Receiver`; the next [`Self::publish`] notices the send
    /// failed and removes it.
    pub fn subscribe(&self) -> Receiver<CapabilityEvent> {
        let (tx, rx) = mpsc::channel();
        self.subscribers.lock().unwrap().push(tx);
        rx
    }

    /// Publishes to every live subscriber. Not durable (see the module
    /// doc): nothing here is written to disk, and a subscriber registered
    /// after this call never sees this event.
    pub fn publish(&self, event: CapabilityEvent) {
        let mut subs = self.subscribers.lock().unwrap();
        subs.retain(|tx| tx.send(event.clone()).is_ok());
    }

    /// How many subscribers are currently registered. Test/diagnostic use —
    /// not part of the capability-facing surface.
    pub fn subscriber_count(&self) -> usize {
        self.subscribers.lock().unwrap().len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_published_event_reaches_a_live_subscriber() {
        let bus = EventBus::new();
        let rx = bus.subscribe();
        bus.publish(CapabilityEvent {
            capability: "notes".into(),
            topic: "note.created".into(),
            payload: b"n1".to_vec(),
        });
        let received = rx.recv().unwrap();
        assert_eq!(received.capability, "notes");
        assert_eq!(received.topic, "note.created");
        assert_eq!(received.payload, b"n1");
    }

    #[test]
    fn every_live_subscriber_gets_its_own_copy() {
        let bus = EventBus::new();
        let rx1 = bus.subscribe();
        let rx2 = bus.subscribe();
        bus.publish(CapabilityEvent {
            capability: "notes".into(),
            topic: "t".into(),
            payload: vec![1, 2, 3],
        });
        assert_eq!(rx1.recv().unwrap().payload, vec![1, 2, 3]);
        assert_eq!(rx2.recv().unwrap().payload, vec![1, 2, 3]);
    }

    /// Nothing published before `subscribe` is ever delivered — there is no
    /// replay buffer, matching the module doc's "not a persistence path."
    #[test]
    fn a_subscriber_never_sees_events_published_before_it_subscribed() {
        let bus = EventBus::new();
        bus.publish(CapabilityEvent {
            capability: "notes".into(),
            topic: "missed".into(),
            payload: vec![],
        });
        let rx = bus.subscribe();
        bus.publish(CapabilityEvent {
            capability: "notes".into(),
            topic: "seen".into(),
            payload: vec![],
        });
        let received = rx.recv().unwrap();
        assert_eq!(received.topic, "seen");
        assert!(rx.try_recv().is_err(), "no second event should arrive");
    }

    /// A dropped receiver is pruned on the next publish rather than
    /// accumulating forever as a dead subscriber.
    #[test]
    fn a_dropped_subscriber_is_pruned_on_the_next_publish() {
        let bus = EventBus::new();
        {
            let _rx = bus.subscribe();
            assert_eq!(bus.subscriber_count(), 1);
        }
        // `_rx` is dropped; the bus does not know yet.
        assert_eq!(bus.subscriber_count(), 1);
        bus.publish(CapabilityEvent {
            capability: "notes".into(),
            topic: "t".into(),
            payload: vec![],
        });
        assert_eq!(
            bus.subscriber_count(),
            0,
            "publish must prune subscribers whose receiver is gone"
        );
    }

    #[test]
    fn a_fresh_bus_has_no_subscribers() {
        let bus = EventBus::new();
        assert_eq!(bus.subscriber_count(), 0);
    }
}
