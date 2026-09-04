import {AiProvider} from "./ai-provider";
import {OpenAiProvider} from "./providers/openai-provider";

/**
 * Factory to return the configured AiProvider.
 *
 * @param {string} apiKey - OpenAI API key.
 * @return {AiProvider} The active AiProvider instance.
 */
export function getAiProvider(apiKey: string): AiProvider {
  const rawProvider = process.env.AI_PROVIDER;
  const providerName = (rawProvider || "openai").trim().toLowerCase();

  switch (providerName) {
  case "openai":
    return new OpenAiProvider(apiKey);
  default:
    throw new Error(
      `Unsupported AI_PROVIDER '${rawProvider}'. ` +
      "Supported providers: 'openai'."
    );
  }
}
