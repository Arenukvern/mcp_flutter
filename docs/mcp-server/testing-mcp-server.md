# Testing Flutter Inspector MCP Server

This guide explains how to test and verify that the Flutter Inspector MCP Server is working correctly.

## 🧪 Quick Verification Tests

### Test 1: Basic Server Functionality

```bash
cd mcp_server_dart

# Test help command
dart run bin/main.dart --help

# Expected output: Command line options and descriptions
```

### Test 2: MCP Protocol Compliance

```bash
# Test MCP protocol responses
dart ../scripts/clean_mcp_test.dart | dart run bin/main.dart --dart-vm-port=8181 2>/dev/null
```

**Expected Output:**

- ✅ Initialization response with protocol version `2024-11-05`
- ✅ Tools list with 4 tools: `hot_reload_flutter`, `get_vm`, `get_extension_rpcs`, `test_custom_ext`
- ✅ Resources list with 3 resources: app errors, screenshots, view details

### Test 3: Executable Compilation

```bash
# Compile to executable
dart compile exe bin/main.dart -o flutter_inspector_mcp_test
chmod +x flutter_inspector_mcp_test

# Test executable
./flutter_inspector_mcp_test --help

# Clean up
rm flutter_inspector_mcp_test
```

## 🔧 Cursor Integration Testing

### Step 1: Build and Configure

```bash
cd mcp_server_dart
dart compile exe bin/main.dart -o flutter_inspector_mcp
chmod +x flutter_inspector_mcp
```

### Step 2: Create Cursor Configuration

Create `~/.cursor/mcp_servers.json`:

```json
{
  "mcpServers": {
    "flutter-inspector": {
      "command": "/absolute/path/to/mcp_flutter/mcp_server_dart/build/flutter_inspector_mcp",
      "args": [
        "--dart-vm-host=localhost",
        "--dart-vm-port=8181",
        "--resources-supported",
        "--images-supported"
      ]
    }
  }
}
```

### Step 3: Test Without Flutter App

1. **Restart Cursor IDE**
2. **Open any project**
3. **Ask Cursor**: _"List available MCP tools"_

**Expected Result**: Cursor should show the Flutter Inspector tools are available, even without a running Flutter app.

### Step 4: Test With Flutter App

1. **Start Flutter app**:

   ```bash
   cd flutter_test_app
   flutter run --debug
   ```

2. **In Cursor, ask**: _"Hot reload my Flutter app"_

**Expected Result**: The Flutter app should hot reload successfully.

## 🐛 Troubleshooting Guide

### Issue: "Unknown method tools/list"

**Cause**: Tools not registered during initialization
**Solution**:

- Ensure you're using the fixed version of the server
- Check that initialization completes successfully
- Verify MCP protocol compliance

### Issue: "VM service not connected"

**Cause**: No Flutter app running or wrong port
**Solutions**:

- Start Flutter app: `flutter run --debug`
- Check port: `lsof -i :8181`
- Verify Flutter app is in debug mode
- Try different port: `--dart-vm-port=8182`

### Issue: "Permission denied"

**Cause**: Executable not properly set up
**Solution**:

```bash
chmod +x flutter_inspector_mcp
```

### Issue: Cursor doesn't detect MCP server

**Causes & Solutions**:

1. **Configuration file location**: Use absolute paths
2. **JSON syntax**: Validate JSON format
3. **Cursor restart**: Restart Cursor after configuration changes
4. **Logs**: Check Cursor logs for connection errors

## 📊 Expected Tool Behaviors

### 1. `hot_reload_flutter`

- **Without Flutter app**: Returns error about VM service not connected
- **With Flutter app**: Successfully reloads and returns reload report

### 2. `get_vm`

- **Without Flutter app**: Returns error about VM service not connected
- **With Flutter app**: Returns VM information (name, version, isolates)

### 3. `get_extension_rpcs`

- **Without Flutter app**: Returns error about VM service not connected
- **With Flutter app**: Returns list of available extension RPCs

### 4. `test_custom_ext`

- **Without Flutter app**: Returns error about VM service not connected
- **With Flutter app**: Tests custom extension and returns results

## 🔍 Advanced Testing

### Manual MCP Protocol Testing

Create a test file `test_mcp.json`:

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{"roots":{"listChanged":true}},"clientInfo":{"name":"test","version":"1.0.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
{"jsonrpc":"2.0","id":3,"method":"resources/list","params":{}}
```

Test with:

```bash
cat test_mcp.json | dart run bin/main.dart --dart-vm-port=8181
```

### Performance Testing

```bash
# Test startup time
time dart run bin/main.dart --help

# Test executable startup time
time ./flutter_inspector_mcp --help
```

### Memory Usage Testing

```bash
# Monitor memory usage during operation
dart run bin/main.dart --dart-vm-port=8181 &
PID=$!
ps -o pid,vsz,rss,comm $PID
kill $PID
```

## ✅ Verification Checklist

- [ ] Server starts without errors
- [ ] Help command works
- [ ] MCP protocol initialization succeeds
- [ ] All 4 tools are registered
- [ ] All 3 resources are available
- [ ] Executable compiles successfully
- [ ] Cursor detects the MCP server
- [ ] Tools work with running Flutter app
- [ ] Graceful error handling without Flutter app

## 🚀 Automated Testing

Run the comprehensive test script:

```bash
./scripts/test_mcp_server.sh
```

Or use the setup script which includes testing:

```bash
./scripts/setup_cursor_mcp.sh
```

## 📝 Test Results Format

When reporting issues, include:

1. **Environment**:

   - OS version
   - Dart SDK version
   - Flutter SDK version
   - Cursor version

2. **Test Commands Used**:

   ```bash
   dart --version
   flutter --version
   dart run bin/main.dart --help
   ```

3. **Error Messages**: Full error output with stack traces

4. **Configuration**: Your `mcp_servers.json` content

5. **Flutter App Status**: Whether Flutter app was running and on which port

## 🔗 Related Documentation

- [Cursor MCP Integration Guide](https://github.com/Arenukvern/mcp_flutter/blob/main/mcp_server_dart/experiments/cursor_mcp_integration.md)
- [Quick Setup Guide](https://github.com/Arenukvern/mcp_flutter/blob/main/mcp_server_dart/experiments/quick_setup_cursor.md)
- [Configuration Options](../getting-started/configuration.md)

---

_This testing guide ensures your Flutter Inspector MCP Server is working correctly with Cursor IDE._
