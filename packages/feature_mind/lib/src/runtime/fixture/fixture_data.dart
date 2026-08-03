/// The design's own numbers, verbatim.
///
/// Fixed timestamps, no clock, no randomness: a golden that moves with the
/// wall clock is a golden that gets deleted. Every value here appears in
/// `Airo Mind Device System.dc.html`, so a fixture screenshot and the design
/// show the same thing.
library;

import '../models/capability_models.dart';
import '../models/context_models.dart';
import '../models/log_models.dart';
import '../models/mesh_models.dart';
import '../models/model_models.dart';
import '../models/vault_models.dart';

/// 2026-08-01T07:12:04Z — the design's "today".
const int fixtureNowMs = 1785827524000;

const int _day = 86400000;

const List<MindContext> fixtureContexts = [
  MindContext(
    id: 'kneesurgery2026',
    label: '#KneeSurgery2026',
    itemCount: 38,
    opCount: 1204,
    openedAtMs: fixtureNowMs - 50 * _day,
    safetyClass: CapabilitySafetyClass.health,
  ),
  MindContext(
    id: 'downtownapartment',
    label: '#DowntownApartment',
    itemCount: 17,
    opCount: 402,
    openedAtMs: fixtureNowMs - 120 * _day,
    safetyClass: CapabilitySafetyClass.general,
  ),
  MindContext(
    id: 'q3taxfiling',
    label: '#Q3TaxFiling',
    itemCount: 52,
    opCount: 918,
    openedAtMs: fixtureNowMs - 90 * _day,
    safetyClass: CapabilitySafetyClass.financial,
  ),
  MindContext(
    id: 'airoarchitecture',
    label: '#AiroArchitecture',
    itemCount: 9,
    opCount: 143,
    openedAtMs: fixtureNowMs - 20 * _day,
    safetyClass: CapabilitySafetyClass.general,
  ),
];

/// The discharge note is linked into both health and tax, which is what makes
/// the survival preview non-trivial. #AiroArchitecture is deliberately
/// unlinked: destroying it must preview an empty survivor set.
const List<ContextLink> fixtureLinks = [
  ContextLink('kneesurgery2026', 'q3taxfiling'),
  ContextLink('downtownapartment', 'q3taxfiling'),
];

/// The nine ops the Windows console shows, newest first.
const List<MindOp> fixtureOps = [
  MindOp(
    sequence: 12481,
    kind: MindOpKind.automation,
    title: 'Ibuprofen 400 mg logged',
    contextId: 'kneesurgery2026',
    deviceName: 'Pixel 9 Pro',
    signature: SignatureState.verified,
    recordedAtMs: fixtureNowMs,
    detail: 'Capability · Hospital Recovery · automation fired on schedule',
  ),
  MindOp(
    sequence: 12477,
    kind: MindOpKind.scan,
    title: 'Bank statement · July, page 2',
    contextId: 'q3taxfiling',
    deviceName: 'Desktop',
    signature: SignatureState.verified,
    recordedAtMs: fixtureNowMs - 800000,
  ),
  MindOp(
    sequence: 12463,
    kind: MindOpKind.merge,
    title: 'Physio plan · week 4 — merged from 2 devices',
    contextId: 'kneesurgery2026',
    deviceName: 'iPad Air',
    signature: SignatureState.verified,
    recordedAtMs: fixtureNowMs - _day,
  ),
  MindOp(
    sequence: 12455,
    kind: MindOpKind.inference,
    title: 'Summarised 3 physio notes · Gemma 3n · 2.1 s',
    contextId: 'kneesurgery2026',
    deviceName: 'Desktop',
    signature: SignatureState.verified,
    recordedAtMs: fixtureNowMs - _day - 3600000,
  ),
  MindOp(
    sequence: 12388,
    kind: MindOpKind.scan,
    title: 'Invoice · Kitchen repair, Basu Contracting',
    contextId: 'q3taxfiling',
    deviceName: 'Pixel 9 Pro',
    signature: SignatureState.verified,
    recordedAtMs: fixtureNowMs - 4 * _day,
    detail: 'Vendor Basu Contracting · contractor invoice · repairs',
  ),
  MindOp(
    sequence: 12341,
    kind: MindOpKind.voice,
    title: '"Call the contractor back" · 0:14',
    contextId: 'downtownapartment',
    deviceName: 'Pixel 9 Pro',
    signature: SignatureState.verified,
    recordedAtMs: fixtureNowMs - 6 * _day,
  ),
  MindOp(
    sequence: 12290,
    kind: MindOpKind.revoke,
    title: 'Key revoked · old laptop removed from mesh',
    contextId: '',
    deviceName: 'Desktop',
    signature: SignatureState.verified,
    recordedAtMs: fixtureNowMs - 10 * _day,
  ),
  MindOp(
    sequence: 12214,
    kind: MindOpKind.import,
    title: 'Email export · quote revision 2',
    contextId: 'downtownapartment',
    deviceName: 'Desktop',
    signature: SignatureState.verified,
    recordedAtMs: fixtureNowMs - 14 * _day,
  ),
  MindOp(
    sequence: 12150,
    kind: MindOpKind.scan,
    title: 'Receipt · hardware store, tiles',
    contextId: 'q3taxfiling',
    deviceName: 'Pixel 9 Pro',
    signature: SignatureState.verified,
    recordedAtMs: fixtureNowMs - 18 * _day,
  ),
];

const List<MindDevice> fixtureDevices = [
  MindDevice(
    name: 'Pixel 9 Pro',
    fingerprint: DeviceFingerprint('4F2A', '9C71', 'E0B3'),
    isThisDevice: true,
    revokedAtMs: null,
  ),
  MindDevice(
    name: 'iPad Air · Studio',
    fingerprint: DeviceFingerprint('81DD', '4A05', '7712'),
    isThisDevice: false,
    revokedAtMs: null,
  ),
  MindDevice(
    name: 'Fold 6 · Pocket',
    fingerprint: DeviceFingerprint('C0F9', '22B8', '5E4D'),
    isThisDevice: false,
    revokedAtMs: null,
  ),
  MindDevice(
    name: 'MacBook · Old',
    fingerprint: DeviceFingerprint('A731', '0C4E', '9982'),
    isThisDevice: false,
    revokedAtMs: fixtureNowMs - 28 * _day,
  ),
];

const List<MindPeer> fixturePeers = [
  MindPeer(
    deviceName: 'iPad Air · Studio',
    fingerprint: DeviceFingerprint('81DD', '4A05', '7712'),
    liveness: PeerLiveness.live,
    opsBehind: 0,
    lastSeenMs: fixtureNowMs - 41000,
  ),
  MindPeer(
    deviceName: 'Fold 6 · Pocket',
    fingerprint: DeviceFingerprint('C0F9', '22B8', '5E4D'),
    liveness: PeerLiveness.stale,
    opsBehind: 14,
    lastSeenMs: fixtureNowMs - 6 * 3600000,
  ),
  MindPeer(
    deviceName: 'Home NAS',
    fingerprint: DeviceFingerprint('5B10', 'EE33', '0147'),
    liveness: PeerLiveness.offline,
    opsBehind: 212,
    lastSeenMs: fixtureNowMs - 3 * _day,
  ),
];

const PairingRequest fixturePairingRequest = PairingRequest(
  deviceName: 'Pixel Watch 3',
  code: '492716',
  requestedAtMs: fixtureNowMs - 30000,
);

const List<InstalledCapability> fixtureCapabilities = [
  InstalledCapability(
    id: 'hospital_recovery',
    name: 'Hospital Recovery',
    version: '1.4',
    isFirstParty: true,
    isActive: true,
    itemCount: 38,
    safetyClass: CapabilitySafetyClass.health,
  ),
  InstalledCapability(
    id: 'property_maintenance',
    name: 'Property Maintenance',
    version: '0.9',
    isFirstParty: true,
    isActive: true,
    itemCount: 17,
    safetyClass: CapabilitySafetyClass.general,
  ),
  InstalledCapability(
    id: 'tax_2026',
    name: 'Tax 2026',
    version: '2.0',
    isFirstParty: true,
    isActive: true,
    itemCount: 52,
    safetyClass: CapabilitySafetyClass.financial,
  ),
  InstalledCapability(
    id: 'audio_scribe',
    name: 'Audio Scribe',
    version: '1.1',
    isFirstParty: true,
    isActive: true,
    itemCount: 4,
    safetyClass: CapabilitySafetyClass.general,
    requiresConsentFor: ['mic'],
  ),
  InstalledCapability(
    id: 'prompt_lab',
    name: 'Prompt Lab',
    version: '1.0',
    isFirstParty: true,
    isActive: true,
    itemCount: 0,
    safetyClass: CapabilitySafetyClass.general,
  ),
];

const List<MindModel> fixtureModels = [
  MindModel(
    id: 'gemma_3n_e4b',
    name: 'Gemma 3n E4B · LiteRT',
    sizeBytes: 1900000000,
    residency: ModelResidency.loaded,
    bench: ModelBench(
      tokensPerSecond: 24.1,
      firstTokenMs: 380,
      residentBytes: 1900000000,
      batteryPercentPerHour: 6,
      measuredUnder: ThermalState.nominal,
      measuredAtMs: fixtureNowMs - 600000,
    ),
  ),
  MindModel(
    id: 'phi_4_mini',
    name: 'Phi-4 mini · 3.8B',
    sizeBytes: 2600000000,
    residency: ModelResidency.available,
  ),
  MindModel(
    id: 'whisper_small',
    name: 'Whisper small · EN/HI',
    sizeBytes: 480000000,
    residency: ModelResidency.resident,
    heldBy: 'Audio Scribe',
  ),
  MindModel(
    id: 'embed_mini',
    name: 'Embed-mini · 384d',
    sizeBytes: 120000000,
    residency: ModelResidency.resident,
    heldBy: 'Vector projection',
  ),
  MindModel(
    id: 'qwen3_4b',
    name: 'Qwen 3 · 4B instruct',
    sizeBytes: 2800000000,
    residency: ModelResidency.available,
  ),
];
