import '../../domain/services/agent_connector.dart';
import 'life_track_status_connector_factory_stub.dart'
    if (dart.library.io) 'life_track_status_connector_factory_io.dart'
    as platform;

AgentConnector? createLifeTrackStatusConnector() =>
    platform.createLifeTrackStatusConnector();

AgentConnector? createLifeTrackRecordConnector() =>
    platform.createLifeTrackRecordConnector();

Future<void> initializeLifeTrackStatusConnector() =>
    platform.initializeLifeTrackStatusConnector();

Future<void> closeLifeTrackStatusConnector() =>
    platform.closeLifeTrackStatusConnector();
