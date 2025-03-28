import { interpreter as py, PyModule } from "node-calls-python";

// https://www.npmjs.com/package/node-calls-python
class PyAgent {
  private pymodule: PyModule;
  constructor() {
    py.addImportPath("../venv/Lib/site-packages");

    this.pymodule = py.importSync("", true);
  }

  async run(code: string) {
    const result = await py.eval(this.pymodule, code);
    return result;
  }
}

export default PyAgent;
