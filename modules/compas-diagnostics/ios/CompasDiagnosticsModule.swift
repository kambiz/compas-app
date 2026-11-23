import ExpoModulesCore

// Stub: no native crash store on iOS yet.
public class CompasDiagnosticsModule: Module {
  public func definition() -> ModuleDefinition {
    Name("CompasDiagnostics")

    Function("getPendingReport") { () -> [String: String]? in
      return nil
    }

    Function("clearReport") { (id: String) -> Bool in
      return false
    }

    Function("copyReport") { (id: String) -> Bool in
      return false
    }

    Function("recordJsError") { (message: String, stack: String?, fatal: Bool) -> Bool in
      return false
    }
  }
}
