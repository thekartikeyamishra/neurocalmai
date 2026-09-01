/* eslint-disable linebreak-style */
/* eslint-disable eol-last */
/* eslint-disable linebreak-style */
/* eslint-disable object-curly-spacing */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { GoogleGenerativeAI } from "@google/generative-ai";

// Initialize the Gemini SDK.
// We expect the API key to be stored securely in Firebase Secret Manager.
const apiKey = process.env.GEMINI_API_KEY || "";
const genAI = new GoogleGenerativeAI(apiKey);

/**
 * Securely routes user transcripts to Gemini for CBT reframing.
 * Called directly from the Flutter app via FirebaseCallable.
 */
export const generateCBTReframe = onCall(
  {
    enforceAppCheck: false, // Set to true later if you configure App Check
    secrets: ["GEMINI_API_KEY"], // Automatically loads the secret at runtime
    maxInstances: 10, // Prevents billing spikes
  },
  async (request) => {
    // 1. Security: Ensure the user is logged in before processing AI
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }

    const userText = request.data.userText;
    if (!userText || typeof userText !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "The function must be called with a valid 'userText' string."
      );
    }

    try {
      // 2. Configure the Gemini 1.5 Flash Model
      // Highly cost-effective, extremely fast, natively supports JSON.
      const model = genAI.getGenerativeModel({
        model: "gemini-1.5-flash",
        generationConfig: {
          responseMimeType: "application/json",
          temperature: 0.2, // Low temperature for clinical consistency
        },
      });

      // 3. Construct the System Prompt
      const prompt = `
        You are an expert Cognitive Behavioral Therapy (CBT) assistant.
        Analyze the following anxious thought or vent from a user.
        
        Identify the primary cognitive distortion.
        Provide a compassionate but objective reframe.
        Provide one immediate, grounding action step.
        
        Output strictly in this JSON format:
        {
          "distortion": "Name of the distortion",
          "reframe": "The reframed thought",
          "action": "A short, actionable next step"
        }
        
        User's thought: "${userText}"
      `;

      // 4. Call the AI
      const result = await model.generateContent(prompt);
      const responseText = result.response.text();

      // 5. Parse and return the structured JSON directly to the mobile app
      return JSON.parse(responseText);
    } catch (error) {
      console.error("🚨 Gemini API Error:", error);
      throw new HttpsError(
        "internal",
        "Failed to generate CBT reframe. Please try again."
      );
    }
  }
);