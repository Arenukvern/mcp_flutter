final class LiveEditSchemas {
  const LiveEditSchemas._();

  static const Map<String, dynamic> resolutionProposal = <String, dynamic>{
    'type': 'object',
    'required': <String>[
      'proposalId',
      'backendId',
      'summary',
      'patch',
      'changedFiles',
      'filePatches',
      'expectedRuntimeEffects',
      'validationSteps',
      'warnings',
      'riskFlags',
    ],
    'properties': <String, dynamic>{
      'proposalId': <String, dynamic>{'type': 'string'},
      'backendId': <String, dynamic>{'type': 'string'},
      'summary': <String, dynamic>{'type': 'string'},
      'patch': <String, dynamic>{'type': 'string'},
      'changedFiles': <String, dynamic>{
        'type': 'array',
        'items': <String, dynamic>{'type': 'string'},
      },
      'filePatches': <String, dynamic>{
        'type': 'array',
        'items': <String, dynamic>{
          'type': 'object',
          'required': <String>['path', 'content'],
          'properties': <String, dynamic>{
            'path': <String, dynamic>{'type': 'string'},
            'content': <String, dynamic>{'type': 'string'},
            'patch': <String, dynamic>{'type': 'string'},
            'meta': <String, dynamic>{
              'type': 'object',
              'additionalProperties': true,
            },
          },
          'additionalProperties': false,
        },
      },
      'expectedRuntimeEffects': <String, dynamic>{
        'type': 'array',
        'items': <String, dynamic>{'type': 'string'},
      },
      'validationSteps': <String, dynamic>{
        'type': 'array',
        'items': <String, dynamic>{'type': 'string'},
      },
      'warnings': <String, dynamic>{
        'type': 'array',
        'items': <String, dynamic>{'type': 'string'},
      },
      'riskFlags': <String, dynamic>{
        'type': 'array',
        'items': <String, dynamic>{'type': 'string'},
      },
      'meta': <String, dynamic>{'type': 'object', 'additionalProperties': true},
    },
    'additionalProperties': false,
  };
}
