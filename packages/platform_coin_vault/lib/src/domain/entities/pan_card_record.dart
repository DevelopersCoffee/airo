import 'package:equatable/equatable.dart';

import '../validators/pan_validator.dart';

/// A PAN card reference stored in the Airo Coin vault.
class PanCardRecord extends Equatable {
  PanCardRecord({
    required this.id,
    required this.panNumber,
    required this.nameOnCard,
    this.fathersName,
    this.dateOfBirth,
    this.cardImageBlob,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now() {
    if (!isValidPan(panNumber)) {
      throw ArgumentError.value(panNumber, 'panNumber', 'Not a valid PAN number');
    }
  }

  final int? id;
  final String panNumber;
  final String nameOnCard;
  final String? fathersName;
  final DateTime? dateOfBirth;
  final List<int>? cardImageBlob;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    panNumber,
    nameOnCard,
    fathersName,
    dateOfBirth,
    cardImageBlob,
    createdAt,
  ];
}
