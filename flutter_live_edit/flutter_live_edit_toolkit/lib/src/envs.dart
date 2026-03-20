// ignore_for_file: do_not_use_environment

const liveEditTestModeFromDefine = bool.fromEnvironment('LIVE_EDIT_TEST_MODE');
const liveEditBackendIdFromDefine = String.fromEnvironment(
  'LIVE_EDIT_BACKEND',
  defaultValue: 'codex_exec',
);
const liveEditWorkingDirectoryFromDefine = String.fromEnvironment(
  'LIVE_EDIT_WORKING_DIRECTORY',
);
