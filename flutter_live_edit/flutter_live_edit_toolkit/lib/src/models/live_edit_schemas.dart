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
          'required': <String>['path', 'content', 'patch'],
          'properties': <String, dynamic>{
            'path': <String, dynamic>{'type': 'string'},
            'content': <String, dynamic>{'type': 'string'},
            'patch': <String, dynamic>{'type': 'string'},
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
    },
    'additionalProperties': false,
  };

  static const Map<String, dynamic> directApplyExecution = <String, dynamic>{
    'type': 'object',
    'required': <String>[
      'summary',
      'changedFiles',
      'warnings',
      'validationSteps',
    ],
    'properties': <String, dynamic>{
      'summary': <String, dynamic>{'type': 'string'},
      'changedFiles': <String, dynamic>{
        'type': 'array',
        'items': <String, dynamic>{'type': 'string'},
      },
      'warnings': <String, dynamic>{
        'type': 'array',
        'items': <String, dynamic>{'type': 'string'},
      },
      'validationSteps': <String, dynamic>{
        'type': 'array',
        'items': <String, dynamic>{'type': 'string'},
      },
    },
    'additionalProperties': false,
  };

  static const Map<String, dynamic> protocolV2Transaction = <String, dynamic>{
    'type': 'object',
    'required': <String>[
      'protocolVersion',
      'compatibilityMode',
      'transactionId',
      'sessionId',
      'baseRevision',
      'workingRevision',
      'intent',
      'targets',
      'patch',
      'validation',
      'apply',
      'rollback',
      'graph',
    ],
    'properties': <String, dynamic>{
      'protocolVersion': <String, dynamic>{
        'type': 'string',
        'enum': <String>['live_edit_protocol/v2'],
      },
      'compatibilityMode': <String, dynamic>{
        'type': 'string',
        'enum': <String>['native_v2', 'point_bubble_v1'],
      },
      'transactionId': <String, dynamic>{'type': 'string'},
      'sessionId': <String, dynamic>{'type': 'string'},
      'baseRevision': <String, dynamic>{'type': 'integer'},
      'workingRevision': <String, dynamic>{'type': 'integer'},
      'intent': <String, dynamic>{
        'type': 'object',
        'required': <String>['intentId', 'summary', 'author', 'issuedAtMs'],
        'properties': <String, dynamic>{
          'intentId': <String, dynamic>{'type': 'string'},
          'summary': <String, dynamic>{'type': 'string'},
          'author': <String, dynamic>{'type': 'string'},
          'issuedAtMs': <String, dynamic>{'type': 'integer'},
          'tags': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{'type': 'string'},
          },
          'metadata': <String, dynamic>{'type': 'object'},
        },
        'additionalProperties': false,
      },
      'targets': <String, dynamic>{
        'type': 'array',
        'items': <String, dynamic>{
          'type': 'object',
          'required': <String>['kind', 'key'],
          'properties': <String, dynamic>{
            'kind': <String, dynamic>{
              'type': 'string',
              'enum': <String>['screen', 'widget', 'animation', 'state'],
            },
            'key': <String, dynamic>{'type': 'string'},
            'screenId': <String, dynamic>{'type': 'string'},
            'widgetId': <String, dynamic>{'type': 'string'},
            'animationId': <String, dynamic>{'type': 'string'},
            'statePath': <String, dynamic>{'type': 'string'},
            'selectionKey': <String, dynamic>{'type': 'string'},
            'propertyPath': <String, dynamic>{
              'type': 'array',
              'items': <String, dynamic>{'type': 'string'},
            },
            'metadata': <String, dynamic>{'type': 'object'},
          },
          'additionalProperties': false,
        },
      },
      'patch': <String, dynamic>{
        'type': 'array',
        'items': <String, dynamic>{
          'type': 'object',
          'required': <String>['operationId', 'op', 'path'],
          'properties': <String, dynamic>{
            'operationId': <String, dynamic>{'type': 'string'},
            'op': <String, dynamic>{
              'type': 'string',
              'enum': <String>['set', 'add', 'remove', 'replace', 'move'],
            },
            'path': <String, dynamic>{'type': 'string'},
            'value': <String, dynamic>{},
            'fromPath': <String, dynamic>{'type': 'string'},
            'metadata': <String, dynamic>{'type': 'object'},
          },
          'additionalProperties': false,
        },
      },
      'validation': <String, dynamic>{
        'type': 'array',
        'items': <String, dynamic>{
          'type': 'object',
          'required': <String>['stepId', 'description', 'required', 'status'],
          'properties': <String, dynamic>{
            'stepId': <String, dynamic>{'type': 'string'},
            'description': <String, dynamic>{'type': 'string'},
            'required': <String, dynamic>{'type': 'boolean'},
            'status': <String, dynamic>{
              'type': 'string',
              'enum': <String>['pending', 'passed', 'failed', 'skipped'],
            },
            'details': <String, dynamic>{'type': 'object'},
          },
          'additionalProperties': false,
        },
      },
      'apply': <String, dynamic>{
        'type': 'object',
        'required': <String>['status', 'runtimeAction'],
        'properties': <String, dynamic>{
          'status': <String, dynamic>{
            'type': 'string',
            'enum': <String>[
              'pending',
              'applied',
              'failed',
              'rolled_back',
              'skipped',
            ],
          },
          'appliedAtMs': <String, dynamic>{'type': 'integer'},
          'runtimeAction': <String, dynamic>{
            'type': 'string',
            'enum': <String>['none', 'hot_reload', 'hot_restart'],
          },
          'details': <String, dynamic>{'type': 'object'},
        },
        'additionalProperties': false,
      },
      'rollback': <String, dynamic>{
        'type': 'object',
        'required': <String>['policy', 'triggered'],
        'properties': <String, dynamic>{
          'policy': <String, dynamic>{
            'type': 'string',
            'enum': <String>[
              'never',
              'on_conflict',
              'on_validation_failure',
              'manual',
            ],
          },
          'reason': <String, dynamic>{'type': 'string'},
          'triggered': <String, dynamic>{'type': 'boolean'},
          'compensationPatch': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{'type': 'object'},
          },
          'metadata': <String, dynamic>{'type': 'object'},
        },
        'additionalProperties': false,
      },
      'graph': <String, dynamic>{
        'type': 'object',
        'required': <String>['nodes'],
        'properties': <String, dynamic>{
          'nodes': <String, dynamic>{
            'type': 'array',
            'items': <String, dynamic>{
              'type': 'object',
              'required': <String>['nodeId', 'kind', 'status'],
              'properties': <String, dynamic>{
                'nodeId': <String, dynamic>{'type': 'string'},
                'kind': <String, dynamic>{
                  'type': 'string',
                  'enum': <String>[
                    'intent',
                    'target',
                    'patch',
                    'validation',
                    'apply',
                    'rollback',
                  ],
                },
                'status': <String, dynamic>{
                  'type': 'string',
                  'enum': <String>[
                    'pending',
                    'in_progress',
                    'completed',
                    'failed',
                  ],
                },
                'dependsOn': <String, dynamic>{
                  'type': 'array',
                  'items': <String, dynamic>{'type': 'string'},
                },
                'payload': <String, dynamic>{'type': 'object'},
              },
              'additionalProperties': false,
            },
          },
        },
        'additionalProperties': false,
      },
      'uiProjection': <String, dynamic>{'type': 'object'},
      'metadata': <String, dynamic>{'type': 'object'},
    },
    'additionalProperties': false,
  };

  static const Map<String, dynamic> protocolV2TransportEvent =
      <String, dynamic>{
        'type': 'object',
        'required': <String>[
          'eventId',
          'sessionId',
          'transactionId',
          'sequence',
          'timestampMs',
          'type',
        ],
        'properties': <String, dynamic>{
          'eventId': <String, dynamic>{'type': 'string'},
          'sessionId': <String, dynamic>{'type': 'string'},
          'transactionId': <String, dynamic>{'type': 'string'},
          'sequence': <String, dynamic>{'type': 'integer'},
          'timestampMs': <String, dynamic>{'type': 'integer'},
          'type': <String, dynamic>{
            'type': 'string',
            'enum': <String>[
              'transaction_opened',
              'node_status_changed',
              'conflict_detected',
              'rollback_triggered',
              'rollback_completed',
              'projection_updated',
            ],
          },
          'payload': <String, dynamic>{'type': 'object'},
        },
        'additionalProperties': false,
      };
}
