//
//  ClaudeAPIClient.swift
//  ScreenshotApp
//
//  Created by AI Assistant on 04/04/25.
//

import Foundation
import AppKit

class ClaudeAPIClient {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    init() {
        // Try to get API key from environment variable first
        if let envApiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envApiKey.isEmpty {
            apiKey = envApiKey
            print("API key found in environment variable")
        } else {
            // Fallback to a hardcoded value (replace with your actual API key if needed)
            apiKey = "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"
            print("Using hardcoded API key")
        }
    }
    
    func formatImageText(image: NSImage, prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Convert NSImage to base64
        guard let base64Image = convertImageToBase64(image) else {
            completion(.failure(APIError.imageConversionFailed))
            return
        }
        
        // Create request URL
        guard let url = URL(string: baseURL) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        // Set up the request with proper headers for Anthropic API
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 60
        
        // Create request body
        let requestBody: [String: Any] = [
            "model": "claude-3-5-haiku-20241022",
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": base64Image]]
                    ]
                ]
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
        print("Request URL: \(url.absoluteString)")
        var headers = request.allHTTPHeaderFields ?? [:]
        if let authHeader = headers["x-api-key"] {
            let prefix = authHeader.prefix(4)
            headers["x-api-key"] = "\(prefix)..." // Mask most of the API key
        }
        print("Actual Request Headers: \(request.allHTTPHeaderFields ?? [:])")
        print("Masked Request Headers: \(headers)")
        
        // Send request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                
                // Check for specific URLError types
                if let urlError = error as? URLError {
                    print("URL Error Code: \(urlError.code.rawValue)")
                    // If the specific error is "host could not be found"
                    if urlError.code == .cannotFindHost {
                        print("Cannot find host - this might be a network connectivity issue or DNS problem")
                    }
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
                    print("Claude API Response: \(responseString)")
                }
                
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // Parse the response according to Claude API v1 format
                if let content = json?["content"] as? [[String: Any]] {
                    let textContent = content.compactMap { item -> String? in
                        if (item["type"] as? String) == "text" {
                            return item["text"] as? String
                        }
                        return nil
                    }.joined(separator: "\n")
                    
                    if !textContent.isEmpty {
                        completion(.success(textContent))
                        return
                    }
                }
                
                // Alternative format with response in message
                if let message = json?["message"] as? [String: Any],
                   let content = message["content"] as? [[String: Any]] {
                    
                    let textContent = content.compactMap { item -> String? in
                        if (item["type"] as? String) == "text" {
                            return item["text"] as? String
                        }
                        return nil
                    }.joined(separator: "\n")
                    
                    if !textContent.isEmpty {
                        completion(.success(textContent))
                        return
                    }
                }
                
                // Try to parse the error message
                if let errorObj = json?["error"] as? [String: Any],
                   let message = errorObj["message"] as? String {
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
    
    enum APIError: Error {
        case imageConversionFailed
        case noData
        case parseError
        case apiError(String)
        case invalidURL
    }
} 