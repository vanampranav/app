import {runOrchestratorTests} from "./orchestrator.test";

runOrchestratorTests().catch((err) => {
  console.error("Test execution failed:", err);
  process.exit(1);
});
