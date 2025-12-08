class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;
  final bool isPrimary;
  final String relationship;
  final String? email;
  final String? notes;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.isPrimary,
    required this.relationship,
    this.email,
    this.notes,
  });

  // Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'isPrimary': isPrimary ? 1 : 0,
      'relationship': relationship,
      'email': email,
      'notes': notes,
    };
  }

  // Create from Map (database retrieval)
  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      id: map['id'] as String,
      name: map['name'] as String,
      phoneNumber: map['phoneNumber'] as String,
      isPrimary: (map['isPrimary'] as int) == 1,
      relationship: map['relationship'] as String,
      email: map['email'] as String?,
      notes: map['notes'] as String?,
    );
  }

  // Create a copy with updated fields
  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    bool? isPrimary,
    String? relationship,
    String? email,
    String? notes,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isPrimary: isPrimary ?? this.isPrimary,
      relationship: relationship ?? this.relationship,
      email: email ?? this.email,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'EmergencyContact{id: $id, name: $name, phoneNumber: $phoneNumber, isPrimary: $isPrimary, relationship: $relationship, email: $email, notes: $notes}';
  }
}
