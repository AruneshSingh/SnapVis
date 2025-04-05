//
//  GeminiAPIClient.swift
//  ScreenshotApp
//
//  Created by AI Assistant on 04/17/25.
//

import Foundation
import AppKit
import PostHog

class GeminiAPIClient {
    private let apiKey: String
    private let model = "gemini-2.0-flash"
    private var baseURL: String {
        return "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
    }
    
    init() {
        // Try to get API key from environment variable first
        if let envApiKey = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"], !envApiKey.isEmpty {
            apiKey = envApiKey
            print("API key found in environment variable")
        } else {
            // Fallback to a placeholder (user needs to replace with actual API key)
            apiKey = "AIzaSyBZhHrdy-NY1G3B6vpK16v9ojm47VghSgE"
            print("Using placeholder API key - please replace with your Google API key")
        }
    }
    
    func formatImageText(image: NSImage, prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Convert NSImage to base64
        guard let base64Image = convertImageToBase64(image) else {
            completion(.failure(APIError.imageConversionFailed))
            return
        }
        
        // Create request URL with API key
        guard var urlComponents = URLComponents(string: baseURL) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        // Add API key as query parameter
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        
        guard let url = urlComponents.url else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        // Set up the request with proper headers for Google Gemini API
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        // Create request body for Gemini API
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt],
                        ["inline_data": [
                            "mime_type": "image/jpeg",
                            "data": base64Image
                        ]]
                    ]
                ]
            ],
            "generationConfig": [
                "maxOutputTokens": 1024
            ]
        ]
        
        // Convert request body to JSON data
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        // Print request details for debugging (but mask the API key)
        print("Request URL: \(url.absoluteString.replacingOccurrences(of: apiKey, with: "API_KEY_HIDDEN"))")
        print("Request Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        // Send request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                
                // Check for specific URLError types
                if let urlError = error as? URLError {
                    print("URL Error Code: \(urlError.code.rawValue)")
                }
                
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Response Code: \(httpResponse.statusCode)")
                print("HTTP Response Headers: \(httpResponse.allHeaderFields)")
            }
            
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            
            do {
                // Print the raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Gemini API Response: \(responseString)")
                }
                
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // Parse the response according to Gemini API format
                if let candidates = json?["candidates"] as? [[String: Any]],
                   let firstCandidate = candidates.first,
                   let content = firstCandidate["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let textPart = parts.first,
                   let text = textPart["text"] as? String {
                    
                    // Capture PostHog event with usage metadata
                    self.captureAIEvent(json: json)
                    
                    completion(.success(text))
                    return
                }
                
                // Try to parse the error message
                if let error = json?["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    completion(.failure(APIError.apiError(message)))
                } else {
                    completion(.failure(APIError.parseError))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    private func convertImageToBase64(_ image: NSImage) -> String? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            return nil
        }
        
        return jpegData.base64EncodedString()
    }
    
    private func captureAIEvent(json: [String: Any]?) {
        // Extract metrics from the JSON response
        guard let json = json else { return }
        
        let finishReason = (json["candidates"] as? [[String: Any]])?.first?["finishReason"] as? String ?? "UNKNOWN"
        
        if let usageMetadata = json["usageMetadata"] as? [String: Any] {
            let promptTokenCount = usageMetadata["promptTokenCount"] as? Int ?? 0
            let outputTokenCount = usageMetadata["candidatesTokenCount"] as? Int ?? 0
            
            // Create properties dictionary
            let properties: [String: Any] = [
                "model_used": model,
                "input_tokens": promptTokenCount,
                "output_tokens": outputTokenCount,
                "finish_reason": finishReason
            ]
            
            // Capture the event with PostHog
            PostHogSDK.shared.capture("AI Capture", properties: properties)
        }
    }
    
    enum APIError: Error {
        case imageConversionFailed
        case noData
        case parseError
        case apiError(String)
        case invalidURL
    }
} 